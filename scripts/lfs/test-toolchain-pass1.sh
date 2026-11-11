#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT/scripts/lfs/verify-lfs-archive.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }

bash -n "$VERIFY"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sources"
printf 'GLITCH//CORE LFS integrity fixture\n' > "$tmp/sources/fixture.tar.xz"
digest="$(md5sum "$tmp/sources/fixture.tar.xz" | awk '{print $1}')"
printf '%s  fixture.tar.xz\n' "$digest" > "$tmp/sources/md5sums"

bash "$VERIFY" "$tmp/sources" fixture.tar.xz >/dev/null || fail "Accepted fixture with correct official checksum."
printf '%032d  fixture.tar.xz\n' 0 > "$tmp/sources/md5sums"
if bash "$VERIFY" "$tmp/sources" fixture.tar.xz >/dev/null 2>&1; then
  fail "Accepted an archive with an incorrect checksum."
fi

printf '%s  fixture.tar.xz\n%s  fixture.tar.xz\n' "$digest" "$digest" > "$tmp/sources/md5sums"
if bash "$VERIFY" "$tmp/sources" fixture.tar.xz >/dev/null 2>&1; then
  fail "Accepted a duplicate checksum entry."
fi

printf '%s  another.tar.xz\n' "$digest" > "$tmp/sources/md5sums"
if bash "$VERIFY" "$tmp/sources" fixture.tar.xz >/dev/null 2>&1; then
  fail "Accepted a missing checksum entry."
fi

printf '%s  fixture.tar.xz\n' "$digest" > "$tmp/sources/md5sums"
ln -s fixture.tar.xz "$tmp/sources/symlink.tar.xz"
if bash "$VERIFY" "$tmp/sources" symlink.tar.xz >/dev/null 2>&1; then
  fail "Accepted a symlink in place of a source archive."
fi

if bash "$VERIFY" "$tmp/sources" ../fixture.tar.xz >/dev/null 2>&1; then
  fail "Accepted a path-traversal archive name."
fi

echo "LFS source archive integrity tests: OK"
