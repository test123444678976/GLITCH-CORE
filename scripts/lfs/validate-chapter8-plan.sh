#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/config/lfs-chapter8-build-order.txt"
LOCK="$ROOT/config/lfs-toolchain.lock"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -s "$MANIFEST" ]] || fail "Chapter 8 package manifest is missing."
[[ -s "$LOCK" ]] || fail "LFS toolchain lock is missing."
awk -F'|' '
  /^#/ || NF == 0 { next }
  NF != 3 { print "Invalid manifest row: " $0 > "/dev/stderr"; exit 1 }
  $1 !~ /^[0-9][0-9]$/ { print "Invalid sequence: " $1 > "/dev/stderr"; exit 1 }
  $2 !~ /^[a-z0-9-]+$/ { print "Invalid package name: " $2 > "/dev/stderr"; exit 1 }
  $3 !~ /^[0-9][A-Za-z0-9._-]*$/ { print "Invalid version: " $3 > "/dev/stderr"; exit 1 }
  {
    expected++
    if (($1 + 0) != expected) { print "Non-contiguous order at " $1 > "/dev/stderr"; exit 1 }
    if (seen[$2]++) { print "Duplicate package: " $2 > "/dev/stderr"; exit 1 }
  }
  END { if (expected != 80) { print "Expected 80 Chapter 8 packages; found " expected > "/dev/stderr"; exit 1 } }
' "$MANIFEST" || fail "Chapter 8 manifest validation failed."
for required in \
  '03|glibc|2.44' \
  '30|gcc|16.2.0' \
  '52|python|3.14.7' \
  '75|systemd|261.2' \
  '78|e2fsprogs|1.47.4'; do
  grep -Fxq "$required" "$MANIFEST" || fail "Missing or mismatched LFS 13.1 package pin: $required"
done
grep -Fxq 'LFS_BOOK=13.1-systemd' "$LOCK" || fail "Unexpected LFS book version."
grep -Fxq 'CHAPTER7_STAGES=chroot-bootstrap,chroot-temporary-tools' "$LOCK" || fail "Chapter 7 prerequisite contract is missing."
grep -Fq 'CHAPTER7_TEMPORARY_PACKAGES=' "$LOCK" || fail "Chapter 7 package lock is missing."
echo "GLITCH//CORE LFS 13.1 Chapter 8 package manifest: OK (80 packages)"
echo "NOTE: this validates the official package inventory and order only; it does not build or install packages."
