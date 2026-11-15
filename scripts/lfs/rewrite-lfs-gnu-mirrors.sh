#!/usr/bin/env bash
set -Eeuo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $# -eq 2 ]] || fail "Usage: rewrite-lfs-gnu-mirrors.sh INPUT OUTPUT"
INPUT=$1
OUTPUT=$2

[[ -f "$INPUT" && ! -L "$INPUT" ]] || fail "Input wget-list must be a regular file."
[[ "$INPUT" != "$OUTPUT" ]] || fail "Input and output paths must differ."
[[ ! -L "$OUTPUT" ]] || fail "Refusing a symlinked output path."

mkdir -p "$(dirname "$OUTPUT")"
tmp="$(mktemp "$OUTPUT.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# ftp.gnu.org timed out repeatedly on GitHub-hosted runners. The kernel.org
# mirror publishes the GNU archive tree; the LFS checksum manifest remains
# authoritative, so stale or corrupted mirror content is rejected later.
sed -E \
  -e 's#^https?://ftpmirror\.gnu\.org/#https://mirrors.kernel.org/gnu/#' \
  -e 's#^https?://ftp\.gnu\.org/gnu/#https://mirrors.kernel.org/gnu/#' \
  "$INPUT" > "$tmp"
[[ -s "$tmp" ]] || fail "Normalized wget-list is empty."
mv -f "$tmp" "$OUTPUT"
trap - EXIT

count="$(grep -c '^https://mirrors\.kernel\.org/gnu/' "$OUTPUT" || true)"
echo "GNU source URLs normalized: $count"
