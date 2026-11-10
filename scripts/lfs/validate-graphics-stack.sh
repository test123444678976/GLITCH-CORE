#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${1:-$ROOT/config/graphics-stack.txt}"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || fail "Graphics stack manifest not found: $MANIFEST"

declare -A seen=()
groups=0
packages=0
required=(zlib expat libdrm libpciaccess libxshmfence wayland wayland-protocols libepoxy mesa xorgproto xtrans libxcb libx11 libxext libxfont2 xkeyboard-config xkbcomp xorg-server xorg-xinit xorg-xauth libinput xf86-input-libinput)

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | xargs)"
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^\[[a-z0-9-]+\]$ ]]; then
    ((groups += 1))
    continue
  fi
  [[ "$line" =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] || fail "Invalid package entry: $raw"
  [[ -z "${seen[$line]+x}" ]] || fail "Duplicate package entry: $line"
  seen["$line"]=1
  ((packages += 1))
done < "$MANIFEST"

(( groups >= 4 )) || fail "Expected at least four graphics groups; found $groups"
(( packages >= 15 )) || fail "Graphics manifest unexpectedly small: $packages packages"
for package in "${required[@]}"; do
  [[ -n "${seen[$package]+x}" ]] || fail "Required graphics target is missing: $package"
done

# Mesa and Xorg must remain explicit targets, not merely optional DDX drivers.
[[ -n "${seen[mesa]+x}" ]] || fail "Mesa is missing."
[[ -n "${seen[xorg-server]+x}" ]] || fail "Xorg server is missing."

echo "Graphics stack manifest: OK"
echo "Groups:   $groups"
echo "Packages: $packages"
echo "Required Mesa, Xorg, protocol, and input targets are present."
echo "NOTE: this validates inventory only; it does not resolve release-specific dependencies or build graphics."
