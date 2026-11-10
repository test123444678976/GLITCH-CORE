#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }

echo "[TEST] Validate MATE manifest"
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
grep -q 'GTK 3 runtime library is missing' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer must require the GTK 3 runtime library."
grep -q 'LightDM GTK greeter executable is missing' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer must require the GTK greeter executable."
grep -q 'TARGET="$(realpath -e "$TARGET_INPUT")"' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer must resolve target paths before its host-root safety check."
grep -q 'Refusing to modify the host root filesystem' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "Installer is missing its host-root safety guard."

echo "[TEST] Static installer and safety checks passed"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# A symlink resolving to the host root must never be accepted.
ln -s / "$tmpdir/root-link"
if bash "$ROOT/scripts/lfs/install-mate-config.sh" "$tmpdir/root-link" >/dev/null 2>&1; then
  fail "Installer accepted a symlink resolving to the host root."
fi
if bash "$ROOT/scripts/lfs/check-mate-target.sh" "$tmpdir/root-link" >/dev/null 2>&1; then
  fail "Target preflight accepted a symlink resolving to the host root."
fi

# Use a harmless fake systemctl to exercise installation without changing the host.
mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
STUB
chmod +x "$tmpdir/bin/systemctl"
export SYSTEMCTL_LOG="$tmpdir/systemctl.log"
export PATH="$tmpdir/bin:$PATH"

make_target() {
  local target="$1"
  mkdir -p "$target/etc" "$target/usr/bin" "$target/usr/sbin" \
    "$target/usr/lib/xorg/modules" "$target/usr/lib/dri" \
    "$target/usr/lib/systemd/system" "$target/usr/share/xgreeters"
  for bin in mate-session marco caja Xorg dbus-daemon lightdm-gtk-greeter; do
    printf '#!/bin/sh\nexit 0\n' > "$target/usr/bin/$bin"
    chmod +x "$target/usr/bin/$bin"
  done
  printf '#!/bin/sh\nexit 0\n' > "$target/usr/sbin/lightdm"
  chmod +x "$target/usr/sbin/lightdm"
  touch "$target/usr/lib/libgtk-3.so.0" \
    "$target/usr/lib/libGL.so.1" "$target/usr/lib/libEGL.so.1" \
    "$target/usr/lib/libgbm.so.1" "$target/usr/lib/dri/swrast_dri.so" \
    "$target/usr/share/xgreeters/lightdm-gtk-greeter.desktop" \
    "$target/usr/lib/systemd/system/lightdm.service" \
    "$target/usr/lib/systemd/system/dbus.service"
}

valid="$tmpdir/valid-target"
echo "[TEST] Exercise successful target installation"
make_target "$valid"
bash -x "$ROOT/scripts/lfs/install-mate-config.sh" "$valid" >/dev/null
[[ -s "$valid/etc/lightdm/lightdm.conf" ]] || fail "Installer did not install LightDM configuration."
[[ -s "$valid/usr/share/xsessions/mate.desktop" ]] || fail "Installer did not install the MATE session entry."
grep -Fq -- '--root='"$valid"' enable dbus.service' "$SYSTEMCTL_LOG" ||
  fail "Installer did not enable D-Bus in the target."
grep -Fq -- '--root='"$valid"' enable lightdm.service' "$SYSTEMCTL_LOG" ||
  fail "Installer did not enable LightDM in the target."

# Missing greeter executable must fail before any configuration is written.
echo "[TEST] Exercise missing greeter rejection"
bad="$tmpdir/missing-greeter"
make_target "$bad"
rm "$bad/usr/bin/lightdm-gtk-greeter"
: > "$SYSTEMCTL_LOG"
if bash "$ROOT/scripts/lfs/install-mate-config.sh" "$bad" >/dev/null 2>&1; then
  fail "Installer accepted a target without the GTK greeter executable."
fi
[[ ! -e "$bad/etc/lightdm/lightdm.conf" ]] ||
  fail "Installer wrote configuration before all runtime preflight checks passed."
[[ ! -s "$SYSTEMCTL_LOG" ]] ||
  fail "Installer enabled services after a failed runtime preflight."

# Missing GTK runtime must also fail before writing configuration.
echo "[TEST] Exercise missing GTK rejection"
bad_gtk="$tmpdir/missing-gtk"
make_target "$bad_gtk"
rm "$bad_gtk/usr/lib/libgtk-3.so.0"
if bash "$ROOT/scripts/lfs/install-mate-config.sh" "$bad_gtk" >/dev/null 2>&1; then
  fail "Installer accepted a target without GTK 3."
fi
[[ ! -e "$bad_gtk/etc/lightdm/lightdm.conf" ]] ||
  fail "Installer wrote configuration without GTK 3."

echo "MATE integration configuration: OK"
echo "MATE installer runtime preflight tests: OK"
echo "NOTE: fixture tests do not compile MATE or launch a graphical session."
