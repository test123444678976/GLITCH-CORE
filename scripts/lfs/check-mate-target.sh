#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Read-only post-install check for a completed GLITCH//CORE target rootfs.
TARGET_INPUT="${1:-}"
fail() { echo "ERROR: $*" >&2; exit 2; }
[[ -n "$TARGET_INPUT" ]] || fail "Usage: $0 /absolute/path/to/target-rootfs"
[[ "$TARGET_INPUT" == /* ]] || fail "Target path must be absolute."
[[ -d "$TARGET_INPUT" ]] || fail "Target directory does not exist."
TARGET="$(realpath -e "$TARGET_INPUT")"
[[ "$TARGET" != "/" ]] || fail "Refusing to inspect the host root as a target."
[[ -d "$TARGET/etc" && -d "$TARGET/usr" ]] || fail "Target is missing etc/ or usr/."

ok=0
missing=0
optional_missing=0
check_file() {
  local label="$1" path="$2" mode="${3:-file}"
  if [[ "$mode" == executable ]]; then
    if [[ -x "$TARGET/$path" ]]; then printf '[ OK ] %s\n' "$label"; ok=$((ok + 1)); else printf '[MISS] %s (%s)\n' "$label" "$path"; missing=$((missing + 1)); fi
  else
    if [[ -e "$TARGET/$path" ]]; then printf '[ OK ] %s\n' "$label"; ok=$((ok + 1)); else printf '[MISS] %s (%s)\n' "$label" "$path"; missing=$((missing + 1)); fi
  fi
}
check_optional() {
  local label="$1" path="$2"
  if [[ -e "$TARGET/$path" ]]; then printf '[ OK ] %s\n' "$label"; ok=$((ok + 1)); else printf '[OPT ] %s not installed (%s)\n' "$label" "$path"; optional_missing=$((optional_missing + 1)); fi
}

check_any() {
  local kind="$1" label="$2"; shift 2
  local path candidate found=0
  for path in "$@"; do
    candidate="$TARGET/$path"
    case "$kind" in
      executable) [[ -f "$candidate" && -x "$candidate" ]] && found=1 ;;
      file)       [[ -f "$candidate" ]] && found=1 ;;
      directory)  [[ -d "$candidate" ]] && found=1 ;;
      *) fail "Internal checker error: unknown check kind '$kind'." ;;
    esac
    if (( found )); then
      printf '[ OK ] %s (%s)\n' "$label" "$path"
      ok=$((ok + 1))
      return 0
    fi
  done
  printf '[MISS] %s (expected %s; checked: %s)\n' "$label" "$kind" "$*"
  missing=$((missing + 1))
  return 0
}

echo "GLITCH//CORE — MATE target rootfs inspection"
echo "Target: $TARGET"
echo
echo "== Desktop runtime =="
check_any file "GTK 3 runtime library" usr/lib/libgtk-3.so.0 usr/lib64/libgtk-3.so.0 usr/lib/x86_64-linux-gnu/libgtk-3.so.0
check_any file "GDK 3 runtime library" usr/lib/libgdk-3.so.0 usr/lib64/libgdk-3.so.0 usr/lib/x86_64-linux-gnu/libgdk-3.so.0
check_any file "GLib runtime library" usr/lib/libglib-2.0.so.0 usr/lib64/libglib-2.0.so.0 usr/lib/x86_64-linux-gnu/libglib-2.0.so.0
check_any file "GObject runtime library" usr/lib/libgobject-2.0.so.0 usr/lib64/libgobject-2.0.so.0 usr/lib/x86_64-linux-gnu/libgobject-2.0.so.0
check_any file "Cairo runtime library" usr/lib/libcairo.so.2 usr/lib64/libcairo.so.2 usr/lib/x86_64-linux-gnu/libcairo.so.2
check_any file "Pango runtime library" usr/lib/libpango-1.0.so.0 usr/lib64/libpango-1.0.so.0 usr/lib/x86_64-linux-gnu/libpango-1.0.so.0
check_any file "GdkPixbuf runtime library" usr/lib/libgdk_pixbuf-2.0.so.0 usr/lib64/libgdk_pixbuf-2.0.so.0 usr/lib/x86_64-linux-gnu/libgdk_pixbuf-2.0.so.0
check_file "Compiled GLib schemas" usr/share/glib-2.0/schemas/gschemas.compiled
check_file "MATE session" usr/bin/mate-session executable
check_file "Marco window manager" usr/bin/marco executable
check_file "Caja file manager" usr/bin/caja executable
check_file "MATE session desktop entry" usr/share/xsessions/mate.desktop
check_file "MATE panel" usr/bin/mate-panel executable
check_file "MATE settings daemon" usr/bin/mate-settings-daemon executable
check_file "MATE control center" usr/bin/mate-control-center executable

echo
echo "== Display and login =="
check_file "Xorg server" usr/bin/Xorg executable
if [[ ! -x "$TARGET/usr/bin/Xorg" && -x "$TARGET/usr/lib/Xorg" ]]; then
  printf '[ OK ] Xorg server (usr/lib/Xorg)\n'; ok=$((ok + 1)); missing=$((missing - 1))
fi
check_file "LightDM executable" usr/sbin/lightdm executable
if [[ ! -x "$TARGET/usr/sbin/lightdm" && -x "$TARGET/usr/bin/lightdm" ]]; then
  printf '[ OK ] LightDM executable (usr/bin/lightdm)\n'; ok=$((ok + 1)); missing=$((missing - 1))
fi
check_file "LightDM GTK greeter desktop entry" usr/share/xgreeters/lightdm-gtk-greeter.desktop
check_any executable "LightDM GTK greeter executable" usr/sbin/lightdm-gtk-greeter usr/bin/lightdm-gtk-greeter
check_file "LightDM service unit" usr/lib/systemd/system/lightdm.service
if [[ ! -e "$TARGET/usr/lib/systemd/system/lightdm.service" && -e "$TARGET/lib/systemd/system/lightdm.service" ]]; then
  printf '[ OK ] LightDM service unit (lib/systemd)\n'; ok=$((ok + 1)); missing=$((missing - 1))
fi

echo
echo "== System integration =="
check_file "D-Bus daemon" usr/bin/dbus-daemon executable
if [[ -e "$TARGET/usr/lib/systemd/system/dbus.service" || -e "$TARGET/lib/systemd/system/dbus.service" ]]; then
  printf '[ OK ] D-Bus systemd service\n'; ok=$((ok + 1))
else
  printf '[MISS] D-Bus systemd service\n'; missing=$((missing + 1))
fi
check_optional "NetworkManager daemon" usr/sbin/NetworkManager
check_optional "GVFS volume/filesystem integration" usr/libexec/gvfsd
check_optional "udisks2 storage service" usr/lib/udisks2/udisksd
check_optional "UPower power service" usr/libexec/upowerd
check_optional "Polkit daemon" usr/lib/polkit-1/polkitd
check_optional "MATE terminal" usr/bin/mate-terminal
check_optional "MATE file manager extensions directory" usr/lib/caja/extensions

echo
echo "== Xorg + Mesa graphics gate =="
bash "$ROOT/scripts/lfs/check-graphics-target.sh" "$TARGET"

echo "== Result =="
echo "Present: $ok | Required missing: $missing | Optional missing: $optional_missing"
if (( missing > 0 )); then
  echo "MATE target is NOT ready for integration."
  exit 1
fi
echo "Core MATE target checks passed. Review optional components before making a release."
echo "This is a filesystem check; it does not boot the target or prove graphics work."
