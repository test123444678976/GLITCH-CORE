#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -n "$TARGET" ]] || fail "Usage: $0 /path/to/completed-lfs-rootfs"
[[ "$TARGET" == /* ]] || fail "Target root must be an absolute path."
[[ -d "$TARGET/etc" && -d "$TARGET/usr" ]] || fail "Target does not look like an installed LFS root filesystem."
[[ "$TARGET" != "/" ]] || fail "Refusing to modify the host root filesystem."

# Accept the common Xorg locations used by different upstream build layouts.
[[ -x "$TARGET/usr/bin/mate-session" ]] || fail "MATE session executable is missing."
[[ -x "$TARGET/usr/bin/marco" ]] || fail "Marco window manager is missing."
[[ -x "$TARGET/usr/bin/caja" ]] || fail "Caja file manager is missing."
[[ -x "$TARGET/usr/sbin/lightdm" || -x "$TARGET/usr/bin/lightdm" ]] || fail "LightDM executable is missing."
[[ -x "$TARGET/usr/bin/Xorg" || -x "$TARGET/usr/lib/Xorg" ]] || fail "Xorg server executable is missing."
[[ -e "$TARGET/usr/share/xgreeters/lightdm-gtk-greeter.desktop" ]] || fail "LightDM GTK greeter desktop entry is missing."
[[ -e "$TARGET/usr/lib/systemd/system/lightdm.service" || -e "$TARGET/lib/systemd/system/lightdm.service" ]] || fail "LightDM systemd service is missing."

install -D -m 0644 "$ROOT/config/lightdm/lightdm.conf" \
  "$TARGET/etc/lightdm/lightdm.conf"
install -D -m 0644 "$ROOT/config/xsessions/mate.desktop" \
  "$TARGET/usr/share/xsessions/mate.desktop"

systemctl --root="$TARGET" set-default graphical.target
systemctl --root="$TARGET" enable lightdm.service

echo "GLITCH//CORE MATE session configuration installed."
echo "MATE, Xorg, LightDM and the GTK greeter were detected in the target."
