#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/lfs/rewrite-lfs-gnu-mirrors.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$HELPER" || fail "GNU mirror normalizer has invalid Bash syntax."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/input" <<'EOF'
https://ftpmirror.gnu.org/autoconf/autoconf-2.73.tar.xz
http://ftpmirror.gnu.org/coreutils/coreutils-9.11.tar.xz
https://ftp.gnu.org/gnu/gcc/gcc-16.2.0/gcc-16.2.0.tar.xz
http://ftp.gnu.org/gnu/gawk/gawk-5.4.1.tar.xz
https://mirrors.kernel.org/gnu/binutils/binutils-2.47.tar.xz
https://github.com/example/project/archive/v1.0.tar.gz
EOF

bash "$HELPER" "$tmp/input" "$tmp/output" >/dev/null

cat > "$tmp/expected" <<'EOF'
https://mirrors.kernel.org/gnu/autoconf/autoconf-2.73.tar.xz
https://mirrors.kernel.org/gnu/coreutils/coreutils-9.11.tar.xz
https://mirrors.kernel.org/gnu/gcc/gcc-16.2.0/gcc-16.2.0.tar.xz
https://mirrors.kernel.org/gnu/gawk/gawk-5.4.1.tar.xz
https://mirrors.kernel.org/gnu/binutils/binutils-2.47.tar.xz
https://github.com/example/project/archive/v1.0.tar.gz
EOF

cmp -s "$tmp/expected" "$tmp/output" || fail "GNU mirror normalization changed an unexpected URL or path."
if grep -Eq '^https?://(ftp|ftpmirror)\.gnu\.org/' "$tmp/output"; then
  fail "A direct ftp.gnu.org or ftpmirror.gnu.org URL remains in the normalized list."
fi

echo "LFS GNU mirror normalization regression tests: OK"
