#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${1:-$ROOT/config/mate-stack.txt}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || fail "MATE stack manifest not found: $MANIFEST"

declare -A seen=()
groups=0
packages=0
required=(
  glib gtk3 cairo pango gdk-pixbuf mesa xorg-server
  mate-common mate-desktop mate-menus mate-settings-daemon
  mate-session-manager mate-panel marco caja
  lightdm lightdm-gtk-greeter dbus polkit networkmanager
)

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | xargs)"
  [[ -z "$line" ]] && continue

  if [[ "$line" =~ ^\[[a-z0-9-]+\]$ ]]; then
    ((groups += 1))
    continue
  fi

  [[ "$line" =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] ||
    fail "Invalid manifest entry: $raw"

  [[ -z "${seen[$line]+x}" ]] || fail "Duplicate package entry: $line"
  seen["$line"]=1
  ((packages += 1))
done < "$MANIFEST"

(( groups >= 4 )) || fail "Expected at least four package groups; found $groups"
(( packages >= 10 )) || fail "Manifest unexpectedly small: $packages packages"

for package in "${required[@]}"; do
  [[ -n "${seen[$package]+x}" ]] || fail "Required MATE target is missing: $package"
done

echo "MATE stack manifest: OK"
echo "Groups:   $groups"
echo "Packages: $packages"
echo "Required desktop, display, and network targets are present."
echo "NOTE: this validates the target list only; it does not build or install packages."
