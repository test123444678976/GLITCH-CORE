#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }
CHECK="$ROOT/scripts/lfs/check-graphics-target.sh"
bash -n "$CHECK"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_valid_target() {
  local target="$1" libdir="${2:-usr/lib}" xorg="${3:-usr/bin/Xorg}"
  mkdir -p "$target/etc/X11" "$target/usr/bin" "$target/usr/lib/xorg/modules" "$target/$libdir/dri"
  mkdir -p "$(dirname "$target/$xorg")"
  printf '#!/bin/sh\nexit 0\n' > "$target/$xorg"
  chmod +x "$target/$xorg"
  touch "$target/$libdir/libGL.so.1" "$target/$libdir/libEGL.so.1" "$target/$libdir/libgbm.so.1" "$target/$libdir/dri/swrast_dri.so"
}

# Standard LFS-like /usr/lib layout.
make_valid_target "$tmpdir/valid"
bash "$CHECK" "$tmpdir/valid" >/dev/null

# Accept supported lib64 and libexec alternatives.
make_valid_target "$tmpdir/alternate" usr/lib64 usr/libexec/Xorg
bash "$CHECK" "$tmpdir/alternate" >/dev/null

# Missing Mesa library and software driver must fail.
mkdir -p "$tmpdir/missing-mesa/etc/X11" "$tmpdir/missing-mesa/usr/bin" "$tmpdir/missing-mesa/usr/lib/xorg/modules" "$tmpdir/missing-mesa/usr/lib/dri"
printf '#!/bin/sh\nexit 0\n' > "$tmpdir/missing-mesa/usr/bin/Xorg"
chmod +x "$tmpdir/missing-mesa/usr/bin/Xorg"
touch "$tmpdir/missing-mesa/usr/lib/libEGL.so.1" "$tmpdir/missing-mesa/usr/lib/libgbm.so.1"
if bash "$CHECK" "$tmpdir/missing-mesa" >/dev/null 2>&1; then
  fail "Checker accepted a target missing libGL and swrast."
fi

# A directory named like a shared library must not satisfy a file check.
make_valid_target "$tmpdir/wrong-types"
rm "$tmpdir/wrong-types/usr/lib/libGL.so.1"
mkdir "$tmpdir/wrong-types/usr/lib/libGL.so.1"
if bash "$CHECK" "$tmpdir/wrong-types" >/dev/null 2>&1; then
  fail "Checker accepted a directory in place of libGL.so.1."
fi

# A non-executable Xorg file must not satisfy the server check.
make_valid_target "$tmpdir/non-executable"
chmod -x "$tmpdir/non-executable/usr/bin/Xorg"
if bash "$CHECK" "$tmpdir/non-executable" >/dev/null 2>&1; then
  fail "Checker accepted a non-executable Xorg server."
fi

# Reject incomplete parent paths, relative paths and the host root.
if bash "$CHECK" "$tmpdir/valid/.." >/dev/null 2>&1; then
  fail "Checker accepted an incomplete parent directory."
fi
if bash "$CHECK" "/" >/dev/null 2>&1; then
  fail "Checker accepted the host root filesystem."
fi
if (cd "$tmpdir" && bash "$CHECK" valid >/dev/null 2>&1); then
  fail "Checker accepted a relative target path."
fi

echo "Xorg + Mesa target inspection tests: OK"
echo "NOTE: fixture tests validate file types and paths only; they do not run Xorg or OpenGL."
