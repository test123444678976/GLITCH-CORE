#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/lfs/build-toolchain-chapter5.sh"
PASS1="$ROOT/scripts/lfs/build-toolchain-pass1.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }

bash -n "$SCRIPT" || fail "Chapter 5 toolchain script has invalid Bash syntax."
bash -n "$PASS1" || fail "Pass 1 script has invalid Bash syntax."

for required in \
  'BINUTILS_VERSION="2.47"' \
  'GCC_VERSION="16.2.0"' \
  'LINUX_VERSION="7.3.1"' \
  'GLIBC_VERSION="2.44"' \
  'build_linux_headers' \
  'build_glibc' \
  'build_libstdcxx' \
  '.glitchcore-linux-headers-complete' \
  '.glitchcore-glibc-complete' \
  '.glitchcore-libstdcxx-complete' \
  'make DESTDIR="$LFS" install'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "Chapter 5 script is missing required stage or guard: $required"
done

# The archive verifier prints a status line; command substitution must receive
# only the source path, otherwise tar is given a malformed multi-line argument.
grep -Fq 'verify-lfs-archive.sh" "$SOURCES" "$name" >/dev/null' "$SCRIPT" || fail "Chapter 5 source verification output is not isolated."
grep -Fq 'verify-lfs-archive.sh" "$SOURCES" "$(basename "$found")" >/dev/null' "$PASS1" || fail "Pass 1 source verification output is not isolated."

# Guard test: a workspace without the official source manifest must fail before
# attempting any package build.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/lfs/sources" "$tmp/lfs/tools"
if LFS="$tmp/lfs" LFS_TGT=x86_64-lfs-linux-gnu bash "$SCRIPT" >/dev/null 2>&1; then
  fail "Chapter 5 build accepted an empty LFS source workspace."
fi

echo "LFS Chapter 5 toolchain regression tests: OK"
