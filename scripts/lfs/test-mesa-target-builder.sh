#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-mesa-target.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$BUILDER"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root/etc" "$tmp/root/usr/bin" "$tmp/root/bin" "$tmp/sources"
printf '#!/bin/sh\nexit 0\n' > "$tmp/root/bin/bash"
printf '#!/bin/sh\nexit 0\n' > "$tmp/root/usr/bin/env"
chmod +x "$tmp/root/bin/bash" "$tmp/root/usr/bin/env"

# Missing target tools must fail before copying sources or mutating the rootfs.
if "$BUILDER" "$tmp/root" "$tmp/sources" >/dev/null 2>&1; then
  fail "Mesa builder accepted a target without Meson/Ninja and target dependencies."
fi
[[ ! -e "$tmp/root/sources" ]] || fail "Preflight failure modified the target rootfs."

if "$BUILDER" "/" "$tmp/sources" >/dev/null 2>&1; then
  fail "Mesa builder accepted the host root."
fi
if (cd "$tmp" && "$BUILDER" root sources >/dev/null 2>&1); then
  fail "Mesa builder accepted a relative target path."
fi

echo "Mesa target builder safety/preflight tests: OK"
echo "NOTE: these tests do not compile Mesa or validate an OpenGL driver."
