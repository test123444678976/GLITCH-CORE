#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash "$ROOT/scripts/lfs/validate-graphics-stack.sh"
bash -n "$ROOT/scripts/lfs/validate-graphics-stack.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cp "$ROOT/config/graphics-stack.txt" "$tmpdir/valid.txt"
sed '/^mesa$/d' "$tmpdir/valid.txt" > "$tmpdir/missing-mesa.txt"
if bash "$ROOT/scripts/lfs/validate-graphics-stack.sh" "$tmpdir/missing-mesa.txt" >/dev/null 2>&1; then
  fail "Graphics validator accepted a manifest without Mesa."
fi
sed '/^xorg-server$/d' "$tmpdir/valid.txt" > "$tmpdir/missing-xorg.txt"
if bash "$ROOT/scripts/lfs/validate-graphics-stack.sh" "$tmpdir/missing-xorg.txt" >/dev/null 2>&1; then
  fail "Graphics validator accepted a manifest without Xorg."
fi
cat "$tmpdir/valid.txt" > "$tmpdir/duplicate.txt"
printf '\nmesa\n' >> "$tmpdir/duplicate.txt"
if bash "$ROOT/scripts/lfs/validate-graphics-stack.sh" "$tmpdir/duplicate.txt" >/dev/null 2>&1; then
  fail "Graphics validator accepted a duplicate package."
fi

echo "Xorg + Mesa graphics inventory tests: OK"
echo "NOTE: these tests do not compile drivers, start Xorg, or prove hardware acceleration."
