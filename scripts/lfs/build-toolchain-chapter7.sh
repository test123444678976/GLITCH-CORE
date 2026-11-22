#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE — LFS 13.1-systemd Chapter 7 temporary tools.
# Host orchestration is root-only; package recipes run inside the LFS chroot.
CHECK_ONLY=0
if [[ "${1:-}" == "--check-only" ]]; then
  CHECK_ONLY=1
  shift
fi
[[ $# -eq 1 ]] || { echo "Usage: $0 [--check-only] /absolute/path/to/LFS-rootfs" >&2; exit 2; }
TARGET_INPUT="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LFS_TGT=x86_64-lfs-linux-gnu
JOBS="${JOBS:-2}"

fail() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

[[ "$TARGET_INPUT" == /* && -d "$TARGET_INPUT" && ! -L "$TARGET_INPUT" ]] || fail "Target must be an existing, non-symlinked absolute directory."
TARGET="$(realpath -e -- "$TARGET_INPUT")"
[[ "$TARGET" != / ]] || fail "Refusing to use the host root filesystem."
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."

for marker in .glitchcore-chapter6-complete .glitchcore-chroot-ready; do
  [[ -f "$TARGET/tools/$marker" && ! -L "$TARGET/tools/$marker" ]] || fail "Required checkpoint marker is missing: $marker"
done
[[ -s "$TARGET/CHAPTER-7-CHROOT-PREP-INFO.txt" ]] || fail "Chapter 7 chroot preparation provenance is missing."
grep -Fxq "LFS_BOOK=13.1-systemd" "$TARGET/CHAPTER-7-CHROOT-PREP-INFO.txt" || fail "Unexpected LFS book version."
grep -Fxq "CHROOT_SMOKE=passed" "$TARGET/CHAPTER-7-CHROOT-PREP-INFO.txt" || fail "The Chapter 7 chroot smoke test has not passed."

for relative in sources tools usr/bin usr/sbin usr/lib dev dev/pts dev/shm proc sys run; do
  [[ -d "$TARGET/$relative" && ! -L "$TARGET/$relative" ]] || fail "Required rootfs directory is missing or unsafe: $relative"
done
[[ -s "$TARGET/sources/wget-list" && -s "$TARGET/sources/md5sums" ]] || fail "Official LFS source manifests are missing."

log "Verifying all eight official LFS 13.1 Chapter 7 source archives"
bash "$ROOT/scripts/lfs/validate-toolchain-chapter7-sources.sh" "$TARGET/sources"

if (( CHECK_ONLY )); then
  echo "Chapter 7 build preflight: OK (no mounts and no package builds performed)."
  exit 0
fi

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires a Linux x86_64 build host."
[[ "$(id -u)" -eq 0 ]] || fail "Run the Chapter 7 build as root."
for cmd in mount umount mountpoint chroot realpath sha256sum tar; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing host command: $cmd"
done
[[ "$TARGET" == "$ROOT/"* || "$TARGET" == "${GITHUB_WORKSPACE:-/nonexistent}/"* ]] || log "Building the explicitly selected LFS rootfs: $TARGET"

for relative in dev dev/pts dev/shm proc sys run; do
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

log "Mounting virtual kernel filesystems"
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
  fail "The Chapter 7 target /dev/shm must be a real directory, not a symlink."
fi
mount -t tmpfs -o nosuid,nodev tmpfs "$TARGET/dev/shm"
MOUNT_SHM=1

log "Building the eight LFS Chapter 7 temporary packages inside chroot"
chroot "$TARGET" /usr/bin/env -i \
  HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin \
  LC_ALL=POSIX MAKEFLAGS="-j$JOBS" TESTSUITEFLAGS="-j$JOBS" \
  /bin/bash --login -s <<'CHROOT_SCRIPT'
set -Eeuo pipefail
umask 022
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin

fail() { echo "ERROR (LFS chroot): $*" >&2; exit 1; }
log() { echo; echo "==> [LFS chroot] $*"; }

extract_source() {
  local archive="$1" directory="$2"
  [[ "$archive" == "$(basename "$archive")" ]] || fail "Unsafe source archive name: $archive"
  [[ -f "/sources/$archive" && ! -L "/sources/$archive" ]] || fail "Missing or unsafe source archive: $archive"
  [[ ! -L "/sources/$directory" ]] || fail "Refusing symlinked source directory: $directory"
  rm -rf -- "/sources/$directory"
  tar -xf "/sources/$archive" -C /sources
  [[ -d "/sources/$directory" && ! -L "/sources/$directory" ]] || fail "Archive did not create expected source directory: $directory"
}

require_marker_outputs() {
  local marker="$1"
  shift
  [[ -f "/tools/$marker" ]] || return 1
  local output
  for output in "$@"; do
    [[ -e "$output" ]] || fail "Marker /tools/$marker exists but expected output is missing: $output"
  done
  return 0
}

# 7.7 Gettext 1.0 — only the three temporary utilities are installed.
if ! require_marker_outputs .glitchcore-ch7-gettext-complete /usr/bin/msgfmt /usr/bin/msgmerge /usr/bin/xgettext; then
  log "Gettext 1.0"
  extract_source gettext-1.0.tar.xz gettext-1.0
  cd /sources/gettext-1.0
  ./configure --disable-shared
  make
  cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin/
  touch /tools/.glitchcore-ch7-gettext-complete
fi

# 7.8 Bison 3.8.2
if ! require_marker_outputs .glitchcore-ch7-bison-complete /usr/bin/bison; then
  log "Bison 3.8.2"
  extract_source bison-3.8.2.tar.xz bison-3.8.2
  cd /sources/bison-3.8.2
  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
  make
  make install
  touch /tools/.glitchcore-ch7-bison-complete
fi

# 7.9 Perl 5.44.0
if ! require_marker_outputs .glitchcore-ch7-perl-complete /usr/bin/perl; then
  log "Perl 5.44.0"
  extract_source perl-5.44.0.tar.xz perl-5.44.0
  cd /sources/perl-5.44.0
  sh Configure -des \
    -D prefix=/usr \
    -D vendorprefix=/usr \
    -D useshrplib \
    -D privlib=/usr/lib/perl5/5.44/core_perl \
    -D archlib=/usr/lib/perl5/5.44/core_perl \
    -D sitelib=/usr/lib/perl5/5.44/site_perl \
    -D sitearch=/usr/lib/perl5/5.44/site_perl \
    -D vendorlib=/usr/lib/perl5/5.44/vendor_perl \
    -D vendorarch=/usr/lib/perl5/5.44/vendor_perl
  make
  make install
  touch /tools/.glitchcore-ch7-perl-complete
fi

# 7.10 Zlib 1.3.2
if ! require_marker_outputs .glitchcore-ch7-zlib-complete /usr/lib/libz.so; then
  log "Zlib 1.3.2"
  extract_source zlib-1.3.2.tar.gz zlib-1.3.2
  cd /sources/zlib-1.3.2
  ./configure --prefix=/usr
  make
  make install
  rm -fv /usr/lib/libz.a
  touch /tools/.glitchcore-ch7-zlib-complete
fi

# 7.11 mpdecimal 4.0.1
if ! require_marker_outputs .glitchcore-ch7-mpdecimal-complete /usr/lib/libmpdec.so; then
  log "mpdecimal 4.0.1"
  extract_source mpdecimal-4.0.1.tar.gz mpdecimal-4.0.1
  cd /sources/mpdecimal-4.0.1
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpdecimal-4.0.1
  make
  make install
  touch /tools/.glitchcore-ch7-mpdecimal-complete
fi

# 7.12 Python 3.14.7
if ! require_marker_outputs .glitchcore-ch7-python-complete /usr/bin/python3; then
  log "Python 3.14.7"
  extract_source Python-3.14.7.tar.xz Python-3.14.7
  cd /sources/Python-3.14.7
  ./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython
  make
  # LFS notes that optional modules depending on later Chapter 8 packages may be absent.
  make install
  touch /tools/.glitchcore-ch7-python-complete
fi

# 7.13 Texinfo 7.3
if ! require_marker_outputs .glitchcore-ch7-texinfo-complete /usr/bin/makeinfo; then
  log "Texinfo 7.3"
  extract_source texinfo-7.3.tar.xz texinfo-7.3
  cd /sources/texinfo-7.3
  ./configure --prefix=/usr
  make
  make install
  touch /tools/.glitchcore-ch7-texinfo-complete
fi

# 7.14 Util-linux 2.42.2
if ! require_marker_outputs .glitchcore-ch7-util-linux-complete /usr/bin/mount; then
  log "Util-linux 2.42.2"
  mkdir -pv /var/lib/hwclock
  extract_source util-linux-2.42.2.tar.xz util-linux-2.42.2
  cd /sources/util-linux-2.42.2
  ./configure --libdir=/usr/lib \
    --runstatedir=/run \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --disable-liblastlog2 \
    --without-python \
    ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --docdir=/usr/share/doc/util-linux-2.42.2
  make
  make install
  touch /tools/.glitchcore-ch7-util-linux-complete
fi

# Verify the temporary toolchain before writing the final completion marker.
/usr/bin/msgfmt --version >/dev/null
/usr/bin/msgmerge --version >/dev/null
/usr/bin/xgettext --version >/dev/null
/usr/bin/bison --version >/dev/null
/usr/bin/perl -e 'print "Perl runtime OK\n"'
/usr/bin/python3 --version
/usr/bin/makeinfo --version >/dev/null
/usr/bin/mount --version >/dev/null
test -s /usr/lib/libz.so
test -s /usr/lib/libmpdec.so
for marker in gettext bison perl zlib mpdecimal python texinfo util-linux; do
  test -f "/tools/.glitchcore-ch7-$marker-complete"
done
touch /tools/.glitchcore-chapter7-temporary-tools-complete
echo "GLITCH//CORE LFS Chapter 7 temporary tools: PASSED"
CHROOT_SCRIPT

log "Unmounting virtual kernel filesystems"
cleanup_mounts || fail "One or more LFS chroot mounts could not be unmounted."
trap - EXIT INT TERM

{
  echo "GLITCH//CORE LFS 13.1-systemd — Chapter 7 temporary tools"
  echo "Target: $LFS_TGT"
  echo "Branch: ${GITHUB_REF_NAME:-manual}"
  echo "Commit: ${GITHUB_SHA:-unknown}"
  echo "Workflow run: ${GITHUB_RUN_ID:-unknown}"
  echo "Packages: Gettext 1.0, Bison 3.8.2, Perl 5.44.0, Zlib 1.3.2, mpdecimal 4.0.1, Python 3.14.7, Texinfo 7.3, Util-linux 2.42.2"
  echo "Status: all eight temporary packages built and verified inside the LFS chroot"
  echo "Source SHA256:"
  for archive in gettext-1.0.tar.xz bison-3.8.2.tar.xz perl-5.44.0.tar.xz zlib-1.3.2.tar.gz mpdecimal-4.0.1.tar.gz Python-3.14.7.tar.xz texinfo-7.3.tar.xz util-linux-2.42.2.tar.xz; do
    sha256sum "$TARGET/sources/$archive"
  done
} > "$TARGET/CHAPTER-7-BUILD-INFO.txt"

touch "$TARGET/tools/.glitchcore-chapter7-temporary-tools-complete"
echo "LFS Chapter 7 temporary tools built and verified."
