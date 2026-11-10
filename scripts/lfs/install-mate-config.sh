#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_INPUT="${1:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -n "$TARGET_INPUT" ]] || fail "Usage: $0 /path/to/completed-lfs-rootfs"
[[ "$TARGET_INPUT" == /* ]] || fail "Target root must be an absolute path."
[[ -d "$TARGET_INPUT" ]] || fail "Target directory does not exist: $TARGET_INPUT"

# Resolve symlinks and '..' before the destructive-target guard.
TARGET="$(realpath -e "$TARGET_INPUT")"
[[ "$TARGET" != "/" ]] || fail "Refusing to modify the host root filesystem."
[[ -d "$TARGET/etc" && -d "$TARGET/usr" ]] || fail "Target does not look like an installed LFS root filesystem."

# Check all runtime components before writing any configuration.
[[ -x "$TARGET/usr/bin/mate-session" ]] || fail "MATE session executable is missing."
[[ -x "$TARGET/usr/bin/marco" ]] || fail "Marco window manager is missing."
[[ -x "$TARGET/usr/bin/caja" ]] || fail "Caja file manager is missing."
[[ -x "$TARGET/usr/sbin/lightdm" || -x "$TARGET/usr/bin/lightdm" ]] || fail "LightDM executable is missing."
[[ -x "$TARGET/usr/bin/Xorg" || -x "$TARGET/usr/lib/Xorg" ]] || fail "Xorg server executable is missing."
[[ -e "$TARGET/usr/share/xgreeters/lightdm-gtk-greeter.desktop" ]] || fail "LightDM GTK greeter desktop entry is missing."
[[ -x "$TARGET/usr/sbin/lightdm-gtk-greeter" || -x "$TARGET/usr/bin/lightdm-gtk-greeter" ]] || fail "LightDM GTK greeter executable is missing."
gtk_found=0
for gtk_library in \
  usr/lib/libgtk-3.so.0 \
  usr/lib64/libgtk-3.so.0 \
  usr/lib/x86_64-linux-gnu/libgtk-3.so.0; do
  if [[ -f "$TARGET/$gtk_library" ]]; then gtk_found=1; break; fi
done
(( gtk_found )) || fail "GTK 3 runtime library is missing."
[[ -e "$TARGET/usr/lib/systemd/system/lightdm.service" || -e "$TARGET/lib/systemd/system/lightdm.service" ]] || fail "LightDM systemd service is missing."
[[ -x "$TARGET/usr/bin/dbus-daemon" ]] || fail "D-Bus daemon executable is missing."
[[ -e "$TARGET/usr/lib/systemd/system/dbus.service" || -e "$TARGET/lib/systemd/system/dbus.service" ]] || fail "D-Bus systemd service is missing."
command -v systemctl >/dev/null 2>&1 || fail "systemctl is required on the build host."

# Do not configure a graphical login until the Xorg + Mesa target passes preflight.
bash "$ROOT/scripts/lfs/check-graphics-target.sh" "$TARGET"

# All preflight checks pass. Only now write configuration and enable services.
install -D -m 0644 "$ROOT/config/lightdm/lightdm.conf" \
  "$TARGET/etc/lightdm/lightdm.conf"
install -D -m 0644 "$ROOT/config/xsessions/mate.desktop" \
  "$TARGET/usr/share/xsessions/mate.desktop"

systemctl --root="$TARGET" set-default graphical.target
systemctl --root="$TARGET" enable dbus.service
systemctl --root="$TARGET" enable lightdm.service

# NetworkManager is recommended but may be omitted from minimal images.
if [[ -e "$TARGET/usr/lib/systemd/system/NetworkManager.service" || -e "$TARGET/lib/systemd/system/NetworkManager.service" ]]; then
  systemctl --root="$TARGET" enable NetworkManager.service
fi

echo "GLITCH//CORE MATE session configuration installed in: $TARGET"
echo "MATE, GTK 3, Xorg, D-Bus, LightDM and the GTK greeter were detected in the target."
echo "D-Bus and LightDM are enabled; NetworkManager is enabled when installed."
