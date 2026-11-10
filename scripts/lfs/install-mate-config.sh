#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -n "$TARGET" ]] || fail "Usage: $0 /path/to/completed-lfs-rootfs"
[[ "$TARGET" == /* ]] || fail "Target root must be an absolute path."
[[ -d "$TARGET/etc" && -d "$TARGET/usr" ]] || fail "Target does not look like an installed LFS root filesystem."
[[ "$TARGET" != "/" ]] || fail "Refusing to modify the host root filesystem."

# Never claim to install MATE itself: this stage integrates configuration
# after the MATE, Xorg, LightDM and systemd packages have been built/installed.
for path in \
  usr/bin/mate-session \
  usr/bin/marco \
  usr/bin/caja \
  usr/bin/Xorg \
  usr/sbin/lightdm \
  usr/share/lightdm/lightdm-gtk-greeter \
  usr/lib/systemd/system/lightdm.service; do
  [[ -e "$TARGET/$path" ]] || fail "Missing prerequisite: /$path (build/install the MATE stack first)"
done

install -D -m 0644 "$ROOT/config/lightdm/lightdm.conf" \
  "$TARGET/etc/lightdm/lightdm.conf"
install -D -m 0644 "$ROOT/config/xsessions/mate.desktop" \
  "$TARGET/usr/share/xsessions/mate.desktop"

# Select graphical boot and enable LightDM inside the target, not on the host.
systemctl --root="$TARGET" set-default graphical.target
systemctl --root="$TARGET" enable lightdm.service

echo "GLITCH//CORE MATE session configuration installed."
echo "MATE packages were expected to be built and installed beforehand."
