#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }
CHECK="$ROOT/scripts/lfs/check-graphics-target.sh"
bash -n "$CHECK"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/valid/etc/X11" "$tmpdir/valid/usr/bin" "$tmpdir/valid/usr/lib/xorg/modules" "$tmpdir/valid/usr/lib/dri"
touch "$tmpdir/valid/usr/bin/Xorg" "$tmpdir/valid/usr/lib/libGL.so.1" "$tmpdir/valid/usr/lib/libEGL.so.1" "$tmpdir/valid/usr/lib/libgbm.so.1" "$tmpdir/valid/usr/lib/dri/swrast_dri.so"
bash "$CHECK" "$tmpdir/valid" >/dev/null

mkdir -p "$tmpdir/missing-mesa/etc" "$tmpdir/missing-mesa/usr/bin" "$tmpdir/missing-mesa/usr/lib/xorg/modules" "$tmpdir/missing-mesa/etc/X11"
touch "$tmpdir/missing-mesa/usr/bin/Xorg" "$tmpdir/missing-mesa/usr/lib/libEGL.so.1" "$tmpdir/missing-mesa/usr/lib/libgbm.so.1"
if bash "$CHECK" "$tmpdir/missing-mesa" >/dev/null 2>&1; then
  fail "Graphics checker accepted a target without the Mesa OpenGL library and DRI software driver."
fi

if bash "$CHECK" "$tmpdir/valid/.." >/dev/null 2>&1; then
  fail "Graphics checker accepted an incomplete parent directory."
fi
if bash "$CHECK" / >/dev/null 2>&1; then
  fail "Graphics checker accepted the host root filesystem."
fi

echo "Xorg + Mesa target inspection tests: OK"
echo "NOTE: fixture tests validate file checks only; they do not run Xorg or OpenGL."
