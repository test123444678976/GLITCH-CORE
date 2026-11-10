#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/scripts/lfs/check-mate-target.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }
bash -n "$CHECK"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
target="$tmp/target"
mkdir -p "$target/etc/X11" "$target/usr/bin" "$target/usr/sbin" \
  "$target/usr/lib/xorg/modules" "$target/usr/lib/dri" \
  "$target/usr/lib/systemd/system" "$target/usr/share/xsessions" \
  "$target/usr/share/xgreeters" "$target/usr/share/glib-2.0/schemas"
for bin in mate-session marco caja mate-panel mate-settings-daemon mate-control-center Xorg dbus-daemon; do
  printf '#!/bin/sh\nexit 0\n' > "$target/usr/bin/$bin"
  chmod +x "$target/usr/bin/$bin"
done
for bin in lightdm lightdm-gtk-greeter; do
  printf '#!/bin/sh\nexit 0\n' > "$target/usr/sbin/$bin"
  chmod +x "$target/usr/sbin/$bin"
done
for lib in libgtk-3.so.0 libgdk-3.so.0 libglib-2.0.so.0 libgobject-2.0.so.0 \
  libcairo.so.2 libpango-1.0.so.0 libgdk_pixbuf-2.0.so.0 libGL.so.1 libEGL.so.1 libgbm.so.1; do
  touch "$target/usr/lib/$lib"
done
touch "$target/usr/lib/dri/swrast_dri.so" \
  "$target/usr/share/glib-2.0/schemas/gschemas.compiled" \
  "$target/usr/share/xsessions/mate.desktop" \
  "$target/usr/share/xgreeters/lightdm-gtk-greeter.desktop" \
  "$target/usr/lib/systemd/system/lightdm.service" \
  "$target/usr/lib/systemd/system/dbus.service"
bash "$CHECK" "$target" >/dev/null

# GTK runtime libraries are required, not merely nice-to-have.
rm "$target/usr/lib/libgtk-3.so.0"
if bash "$CHECK" "$target" >/dev/null 2>&1; then
  fail "MATE target checker accepted a target without GTK 3."
fi
touch "$target/usr/lib/libgtk-3.so.0"

# A greeter desktop file without its executable is not a working login screen.
rm "$target/usr/sbin/lightdm-gtk-greeter"
if bash "$CHECK" "$target" >/dev/null 2>&1; then
  fail "MATE target checker accepted a missing GTK greeter executable."
fi

# Never inspect the host root or accept relative paths.
if bash "$CHECK" "/" >/dev/null 2>&1; then fail "Accepted host root."; fi
if (cd "$tmp" && bash "$CHECK" target >/dev/null 2>&1); then fail "Accepted relative path."; fi
echo "MATE target inspection tests: OK"
echo "NOTE: fixture tests check required files and paths; they do not launch a graphical session."
