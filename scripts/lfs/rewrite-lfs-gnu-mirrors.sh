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

# ftpmirror.gnu.org resolved to a timed-out Savannah endpoint on the hosted
# runner. ftp.gnu.org/gnu/ is the canonical GNU archive path; filenames and
# checksum manifests remain unchanged.
sed -E 's#^https?://ftpmirror\.gnu\.org/#https://ftp.gnu.org/gnu/#' "$INPUT" > "$tmp"
[[ -s "$tmp" ]] || fail "Normalized wget-list is empty."
mv -f "$tmp" "$OUTPUT"
trap - EXIT

count="$(grep -c '^https://ftp\.gnu\.org/gnu/' "$OUTPUT" || true)"
echo "GNU source URLs normalized: $count"
