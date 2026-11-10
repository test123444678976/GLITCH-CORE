#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash "$ROOT/scripts/lfs/validate-mate-stack.sh"

for file in \
  "$ROOT/config/lightdm/lightdm.conf" \
  "$ROOT/config/xsessions/mate.desktop" \
  "$ROOT/scripts/lfs/install-mate-config.sh" \
  "$ROOT/scripts/lfs/check-mate-target.sh" \
  "$ROOT/config/mate-build-order.txt"; do
  [[ -s "$file" ]] || fail "Missing or empty integration file: $file"
done

grep -Eq '^user-session=mate$' "$ROOT/config/lightdm/lightdm.conf" ||
  fail "LightDM is not configured to start the MATE session."
grep -Eq '^Exec=mate-session$' "$ROOT/config/xsessions/mate.desktop" ||
  fail "MATE session desktop entry is invalid."
grep -q 'systemctl --root=.* enable dbus.service' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "D-Bus is not enabled in the target system."
grep -q 'systemctl --root=.* enable lightdm.service' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "LightDM is not enabled in the target system."
bash -n "$ROOT/scripts/lfs/install-mate-config.sh"
bash -n "$ROOT/scripts/lfs/check-mate-target.sh"
bash -n "$ROOT/scripts/lfs/check-graphics-target.sh"
grep -q 'check-graphics-target.sh' "$ROOT/scripts/lfs/check-mate-target.sh" ||
  fail "MATE target inspection must include the Xorg + Mesa graphics gate."
grep -q 'check-graphics-target.sh' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "MATE installer must preflight Xorg + Mesa before enabling graphical login."
grep -q 'TARGET="$(realpath -e "$TARGET_INPUT")"' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer must resolve target paths before its host-root safety check."
grep -q 'Refusing to modify the host root filesystem' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer is missing its host-root safety guard."

# Exercise the safety guard with a symlink that resolves to the host root.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
ln -s / "$tmpdir/root-link"
if bash "$ROOT/scripts/lfs/install-mate-config.sh" "$tmpdir/root-link" >/dev/null 2>&1; then
  fail "Installer accepted a symlink resolving to the host root."
fi
if bash "$ROOT/scripts/lfs/check-mate-target.sh" "$tmpdir/root-link" >/dev/null 2>&1; then
  fail "Target preflight accepted a symlink resolving to the host root."
fi

echo "MATE integration configuration: OK"
echo "NOTE: these checks do not compile MATE or create a desktop ISO."
echo "MATE target preflight script: OK"
