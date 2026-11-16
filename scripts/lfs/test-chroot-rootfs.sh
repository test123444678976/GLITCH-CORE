#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREPARE="$ROOT/scripts/lfs/prepare-chroot-rootfs.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "Run this regression test as root."
bash -n "$PREPARE" || fail "Chroot preparation script has invalid Bash syntax."
grep -Fq 'if mountpoint -q "$TARGET/$relative"; then' "$PREPARE" || fail "Existing mountpoints must be rejected explicitly."
if grep -Fq 'mountpoint -q "$TARGET/$relative" && fail' "$PREPARE"; then fail "Mountpoint guard masks its own failure."; fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

make_fixture() {
  local target="$1"
  mkdir -p "$target/tools" "$target/usr/bin" "$target/usr/sbin" \
    "$target/usr/lib" "$target/lib64"
  touch "$target/tools/.glitchcore-chapter6-complete"
  printf 'fixture\n' > "$target/usr/lib/libc.so.6"
  printf 'fixture\n' > "$target/usr/lib/libstdc++.so.6"
  printf 'fixture\n' > "$target/usr/lib/ld-linux-x86-64.so.2"
  for binary in env bash gcc as ld false head; do
    printf '#!/bin/sh\nexit 0\n' > "$target/usr/bin/$binary"
    chmod 755 "$target/usr/bin/$binary"
  done
  printf '#!/bin/sh\nexit 0\n' > "$target/usr/sbin/chroot"
  chmod 755 "$target/usr/sbin/chroot"
  ln -s usr/bin "$target/bin"
  ln -s usr/lib "$target/lib"
  ln -s usr/sbin "$target/sbin"
  ln -s ../lib/ld-linux-x86-64.so.2 "$target/lib64/ld-linux-x86-64.so.2"
}

target="$tmp/target"
make_fixture "$target"
bash "$PREPARE" --prepare-only "$target" >/dev/null

for required in \
  "$target/etc/hosts" "$target/etc/passwd" "$target/etc/group" \
  "$target/var/log/btmp" "$target/var/log/lastlog" \
  "$target/var/log/faillog" "$target/var/log/wtmp" "$target/home/tester"; do
  [[ -e "$required" ]] || fail "Chapter 7 rootfs preparation omitted: $required"
done

[[ -L "$target/etc/mtab" && "$(readlink "$target/etc/mtab")" == /proc/self/mounts ]] || fail "Incorrect /etc/mtab link."
[[ -L "$target/var/run" && "$(readlink "$target/var/run")" == /run ]] || fail "Incorrect /var/run link."
[[ -L "$target/var/lock" && "$(readlink "$target/var/lock")" == /run/lock ]] || fail "Incorrect /var/lock link."
grep -Fqx 'root:x:0:0:root:/root:/bin/bash' "$target/etc/passwd" || fail "Root account is missing."
grep -Fqx 'tester:x:101:101::/home/tester:/bin/bash' "$target/etc/passwd" || fail "Chapter 8 tester account is missing."
grep -Fqx 'utmp:x:13:' "$target/etc/group" || fail "utmp group is missing."
[[ "$(stat -c '%a' "$target/tmp")" == 1777 ]] || fail "/tmp mode is incorrect."
[[ "$(stat -c '%a' "$target/var/tmp")" == 1777 ]] || fail "/var/tmp mode is incorrect."
[[ "$(stat -c '%a' "$target/root")" == 750 ]] || fail "/root mode is incorrect."
[[ "$(stat -c '%u:%g' "$target/home/tester")" == 101:101 ]] || fail "tester home ownership is incorrect."
[[ "$(stat -c '%g' "$target/var/log/lastlog")" == 13 ]] || fail "lastlog group is incorrect."
[[ "$(stat -c '%a' "$target/var/log/lastlog")" == 664 ]] || fail "lastlog mode is incorrect."
[[ "$(stat -c '%a' "$target/var/log/btmp")" == 600 ]] || fail "btmp mode is incorrect."
[[ ! -e "$target/usr/lib64" && ! -L "$target/usr/lib64" ]] || fail "The forbidden /usr/lib64 directory was created."
[[ ! -e "$target/tools/.glitchcore-chroot-ready" ]] || fail "Preparation-only mode falsely marked the chroot as ready."

# Re-running the layout preparation must be safe and idempotent.
bash "$PREPARE" --prepare-only "$target" >/dev/null

missing_marker="$tmp/missing-marker"
make_fixture "$missing_marker"
rm "$missing_marker/tools/.glitchcore-chapter6-complete"
if bash "$PREPARE" --prepare-only "$missing_marker" >/dev/null 2>&1; then
  fail "Preparation accepted a rootfs without the Chapter 6 completion marker."
fi

bad_link="$tmp/bad-link"
make_fixture "$bad_link"
mkdir -p "$bad_link/var"
ln -s /tmp "$bad_link/var/run"
if bash "$PREPARE" --prepare-only "$bad_link" >/dev/null 2>&1; then
  fail "Preparation accepted an unexpected /var/run symlink."
fi

if bash "$PREPARE" --prepare-only / >/dev/null 2>&1; then
  fail "Preparation accepted the host root filesystem."
fi

echo "LFS Chapter 7 chroot preparation regression tests: OK"
echo "NOTE: fixture tests cover layout and safety; the workflow performs the real chroot smoke test."
