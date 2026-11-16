#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE — LFS 13.1-systemd Chapter 7 chroot bootstrap.
# This prepares the rootfs and performs a real chroot smoke test. It does NOT
# build the Chapter 7 temporary packages.
PREPARE_ONLY=0
if [[ $# -gt 0 && "$1" == "--prepare-only" ]]; then
  PREPARE_ONLY=1
  shift
fi
[[ $# -eq 1 ]] || { echo "Usage: $0 [--prepare-only] /absolute/path/to/LFS-rootfs" >&2; exit 2; }
TARGET_INPUT="$1"
LFS_TGT=x86_64-lfs-linux-gnu
JOBS=2

fail() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires a Linux x86_64 host."
[[ "$(id -u)" -eq 0 ]] || fail "Run this Chapter 7 preparation as root."
[[ "$TARGET_INPUT" == /* && -d "$TARGET_INPUT" ]] || fail "Target must be an existing absolute directory."

TARGET="$(realpath -e -- "$TARGET_INPUT")"
[[ "$TARGET" != / ]] || fail "Refusing to prepare the host root filesystem."
[[ -d "$TARGET/tools" && ! -L "$TARGET/tools" ]] || fail "Chapter 6 tools directory is missing or unsafe."
[[ -f "$TARGET/tools/.glitchcore-chapter6-complete" ]] || fail "Chapter 6 completion marker is missing."

for relative in usr usr/bin usr/sbin usr/lib lib64; do
  [[ -d "$TARGET/$relative" && ! -L "$TARGET/$relative" ]] || fail "Required target directory is missing or unsafe: $relative"
done
for relative in bin lib sbin; do
  [[ -L "$TARGET/$relative" ]] || fail "Merged-/usr symlink is missing: /$relative"
  [[ "$(readlink -- "$TARGET/$relative")" == "usr/$relative" ]] || fail "Unexpected merged-/usr symlink: /$relative"
done

for relative in usr/bin/env usr/bin/bash usr/bin/gcc usr/bin/as usr/bin/ld usr/bin/false usr/bin/head usr/sbin/chroot; do
  [[ -x "$TARGET/$relative" ]] || fail "Required Chapter 6 target executable is missing: $relative"
done
for relative in usr/lib/libc.so.6 usr/lib/libstdc++.so.6 lib64/ld-linux-x86-64.so.2; do
  [[ -s "$TARGET/$relative" ]] || fail "Required Chapter 6 runtime file is missing: $relative"
done
[[ ! -e "$TARGET/usr/lib64" && ! -L "$TARGET/usr/lib64" ]] || fail "LFS requires /usr/lib64 to remain absent."

# Never let a pre-existing target path redirect writes outside the selected rootfs.
for relative in etc var home root boot mnt opt srv media dev proc sys run tmp; do
  [[ ! -L "$TARGET/$relative" ]] || fail "Refusing symlinked target directory: $relative"
done
for relative in etc/passwd etc/group etc/hosts; do
  [[ ! -L "$TARGET/$relative" ]] || fail "Refusing symlinked configuration file: $relative"
done

log "Creating the LFS Chapter 7 directory layout"
mkdir -p \
  "$TARGET/boot" "$TARGET/home" "$TARGET/mnt" "$TARGET/opt" "$TARGET/srv" \
  "$TARGET/dev/pts" "$TARGET/dev/shm" "$TARGET/proc" "$TARGET/sys" "$TARGET/run" \
  "$TARGET/etc/opt" "$TARGET/etc/sysconfig" \
  "$TARGET/lib/firmware" "$TARGET/media/floppy" "$TARGET/media/cdrom" \
  "$TARGET/usr/include" "$TARGET/usr/src" "$TARGET/usr/local/include" "$TARGET/usr/local/src" \
  "$TARGET/usr/lib/locale" "$TARGET/usr/local/bin" "$TARGET/usr/local/lib" "$TARGET/usr/local/sbin" \
  "$TARGET/usr/share/color" "$TARGET/usr/share/dict" "$TARGET/usr/share/doc" \
  "$TARGET/usr/share/info" "$TARGET/usr/share/locale" "$TARGET/usr/share/man" \
  "$TARGET/usr/share/misc" "$TARGET/usr/share/terminfo" "$TARGET/usr/share/zoneinfo" \
  "$TARGET/usr/local/share/color" "$TARGET/usr/local/share/dict" "$TARGET/usr/local/share/doc" \
  "$TARGET/usr/local/share/info" "$TARGET/usr/local/share/locale" "$TARGET/usr/local/share/man" \
  "$TARGET/usr/local/share/misc" "$TARGET/usr/local/share/terminfo" "$TARGET/usr/local/share/zoneinfo" \
  "$TARGET/var/cache" "$TARGET/var/local" "$TARGET/var/log" "$TARGET/var/mail" \
  "$TARGET/var/opt" "$TARGET/var/spool" "$TARGET/var/lib/color" \
  "$TARGET/var/lib/misc" "$TARGET/var/lib/locate"

for section in 1 2 3 4 5 6 7 8; do
  mkdir -p "$TARGET/usr/share/man/man$section" "$TARGET/usr/local/share/man/man$section"
done
install -d -m 0750 "$TARGET/root"
install -d -m 1777 "$TARGET/tmp" "$TARGET/var/tmp"

ensure_symlink() {
  local link_path="$1" link_target="$2"
  if [[ -L "$link_path" ]]; then
    [[ "$(readlink -- "$link_path")" == "$link_target" ]] || fail "Unexpected symlink at $link_path"
  elif [[ -e "$link_path" ]]; then
    fail "Refusing to replace existing non-symlink path: $link_path"
  else
    ln -s "$link_target" "$link_path"
  fi
}
ensure_symlink "$TARGET/etc/mtab" /proc/self/mounts
ensure_symlink "$TARGET/var/run" /run
ensure_symlink "$TARGET/var/lock" /run/lock

write_if_missing() {
  local path="$1"
  [[ ! -L "$path" ]] || fail "Refusing symlinked configuration file: $path"
  if [[ -e "$path" ]]; then
    [[ -f "$path" ]] || fail "Expected a regular file: $path"
  else
    cat > "$path"
  fi
}

log "Creating essential LFS account and host files"
write_if_missing "$TARGET/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1       localhost
EOF
grep -Fqx '127.0.0.1 localhost' "$TARGET/etc/hosts" || fail "/etc/hosts lacks the IPv4 localhost entry."
grep -Fqx '::1       localhost' "$TARGET/etc/hosts" || fail "/etc/hosts lacks the IPv6 localhost entry."

write_if_missing "$TARGET/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
for entry in \
  'root:x:0:0:root:/root:/bin/bash' \
  'messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false' \
  'systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false' \
  'nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false'; do
  grep -Fqx "$entry" "$TARGET/etc/passwd" || fail "Incomplete /etc/passwd; missing: $entry"
done
if ! grep -Fqx 'tester:x:101:101::/home/tester:/bin/bash' "$TARGET/etc/passwd"; then
  printf '%s\n' 'tester:x:101:101::/home/tester:/bin/bash' >> "$TARGET/etc/passwd"
fi

write_if_missing "$TARGET/etc/group" <<'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
clock:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
for entry in 'root:x:0:' 'tty:x:5:' 'utmp:x:13:' 'messagebus:x:18:' 'nogroup:x:65534:'; do
  grep -Fqx "$entry" "$TARGET/etc/group" || fail "Incomplete /etc/group; missing: $entry"
done
if ! grep -Fqx 'tester:x:101:' "$TARGET/etc/group"; then
  printf '%s\n' 'tester:x:101:' >> "$TARGET/etc/group"
fi

touch "$TARGET/var/log/btmp" "$TARGET/var/log/lastlog" \
  "$TARGET/var/log/faillog" "$TARGET/var/log/wtmp"
chgrp 13 "$TARGET/var/log/lastlog"
chmod 664 "$TARGET/var/log/lastlog"
chmod 600 "$TARGET/var/log/btmp"

# The Chapter 7 temporary system is owned by root; source archives remain inputs.
chown -h root:root "$TARGET"
chown -hR root:root \
  "$TARGET/etc" "$TARGET/usr" "$TARGET/var" "$TARGET/tools" "$TARGET/lib64" \
  "$TARGET/home" "$TARGET/root" "$TARGET/boot" "$TARGET/mnt" "$TARGET/opt" \
  "$TARGET/srv" "$TARGET/media" "$TARGET/dev" "$TARGET/proc" "$TARGET/sys" \
  "$TARGET/run" "$TARGET/tmp"
chown -h root:root "$TARGET/bin" "$TARGET/lib" "$TARGET/sbin"
install -o 101 -g 101 -m 0755 -d "$TARGET/home/tester"

[[ "$(stat -c '%a' "$TARGET/tmp")" == 1777 ]] || fail "/tmp must have mode 1777."
[[ "$(stat -c '%a' "$TARGET/var/tmp")" == 1777 ]] || fail "/var/tmp must have mode 1777."
[[ "$(stat -c '%a' "$TARGET/root")" == 750 ]] || fail "/root must have mode 0750."
[[ "$(stat -c '%u:%g' "$TARGET/home/tester")" == 101:101 ]] || fail "The Chapter 8 tester home has the wrong owner."
[[ "$(stat -c '%g' "$TARGET/var/log/lastlog")" == 13 ]] || fail "lastlog must belong to the utmp group (GID 13)."
[[ "$(stat -c '%a' "$TARGET/var/log/lastlog")" == 664 ]] || fail "lastlog must have mode 0664."
[[ "$(stat -c '%a' "$TARGET/var/log/btmp")" == 600 ]] || fail "btmp must have mode 0600."

if (( PREPARE_ONLY )); then
  echo "LFS Chapter 7 chroot filesystem layout tests: preparation-only mode completed."
  exit 0
fi

for cmd in mount umount mountpoint chroot realpath; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing host command: $cmd"
done
for relative in dev proc sys run; do
  if mountpoint -q "$TARGET/$relative"; then
    fail "Refusing to reuse an existing mount at $TARGET/$relative"
  fi
done

MOUNT_DEV=0
MOUNT_DEVPTS=0
MOUNT_PROC=0
MOUNT_SYS=0
MOUNT_RUN=0
MOUNT_SHM=0

cleanup_mounts() {
  local failed=0
  if (( MOUNT_SHM )); then umount "$TARGET/dev/shm" && MOUNT_SHM=0 || failed=1; fi
  if (( MOUNT_RUN )); then umount "$TARGET/run" && MOUNT_RUN=0 || failed=1; fi
  if (( MOUNT_SYS )); then umount "$TARGET/sys" && MOUNT_SYS=0 || failed=1; fi
  if (( MOUNT_PROC )); then umount "$TARGET/proc" && MOUNT_PROC=0 || failed=1; fi
  if (( MOUNT_DEVPTS )); then umount "$TARGET/dev/pts" && MOUNT_DEVPTS=0 || failed=1; fi
  if (( MOUNT_DEV )); then umount "$TARGET/dev" && MOUNT_DEV=0 || failed=1; fi
  return "$failed"
}
cleanup_on_exit() {
  local status=$?
  trap - EXIT
  set +e
  cleanup_mounts || status=1
  exit "$status"
}
trap cleanup_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

log "Mounting virtual kernel filesystems for the LFS chroot"
mount --bind /dev "$TARGET/dev"
MOUNT_DEV=1
mount -t devpts devpts -o gid=5,mode=0620 "$TARGET/dev/pts"
MOUNT_DEVPTS=1
mount -t proc proc "$TARGET/proc"
MOUNT_PROC=1
mount -t sysfs sysfs "$TARGET/sys"
MOUNT_SYS=1
mount -t tmpfs tmpfs "$TARGET/run"
MOUNT_RUN=1
mkdir -p "$TARGET/run/lock"

if [[ -L "$TARGET/dev/shm" ]]; then
  host_shm="$(realpath -m /dev/shm)"
  [[ "$host_shm" == /* ]] || fail "Cannot resolve host /dev/shm safely."
  relative_shm="$(printf '%s' "$host_shm" | sed 's#^/##')"
  [[ -n "$relative_shm" && "$relative_shm" != *".."* ]] || fail "Unsafe host /dev/shm destination."
  mkdir -p "$TARGET/$relative_shm"
else
  [[ -d "$TARGET/dev/shm" ]] || fail "The bound /dev/shm path is not a directory."
  mount -t tmpfs -o nosuid,nodev tmpfs "$TARGET/dev/shm"
  MOUNT_SHM=1
fi

log "Entering the target rootfs and checking its native tools"
chroot "$TARGET" /usr/bin/env -i \
  HOME=/root TERM=dumb \
  PS1='(GLITCH//CORE chroot) \u:\w\$ ' \
  PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$JOBS" \
  TESTSUITEFLAGS="-j$JOBS" \
  /bin/bash --login -c '
    set -Eeuo pipefail
    for binary in /usr/bin/env /usr/bin/bash /usr/bin/gcc /usr/bin/as /usr/bin/ld; do
      [[ -x "$binary" ]] || { echo "Missing target executable: $binary" >&2; exit 1; }
    done
    [[ -s /usr/lib/libc.so.6 && -s /usr/lib/libstdc++.so.6 ]]
    [[ -d /dev/pts && -d /proc && -d /sys && -d /run ]]
    target="$(/usr/bin/gcc -dumpmachine)"
    [[ "$target" == "x86_64-lfs-linux-gnu" ]]
    /usr/bin/bash --version | /usr/bin/head -n 1
    /usr/bin/ld --version | /usr/bin/head -n 1
    echo "GLITCH//CORE native LFS chroot smoke test: PASSED"
    echo "PATH excludes /tools/bin; Chapter 6 target GCC is active."
  '

log "Unmounting virtual kernel filesystems"
cleanup_mounts || fail "One or more LFS chroot mounts could not be unmounted."
trap - EXIT INT TERM

cat > "$TARGET/CHAPTER-7-CHROOT-PREP-INFO.txt" <<EOF
LFS_BOOK=13.1-systemd
TARGET=$LFS_TGT
CHROOT_SMOKE=passed
PATH=/usr/bin:/usr/sbin
CHAPTER7_TEMPORARY_PACKAGES=not-built
EOF
touch "$TARGET/tools/.glitchcore-chroot-ready"

echo "LFS Chapter 7 chroot bootstrap completed and verified."
echo "No Chapter 7 temporary packages have been built by this step."
