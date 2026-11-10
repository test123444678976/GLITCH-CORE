#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only graphics readiness inspection for an installed target rootfs.
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

echo "GLITCH//CORE — Xorg + Mesa target inspection"
echo "Target: $TARGET"
echo
echo "== Xorg server and modules =="
check_any executable "Xorg server executable" usr/bin/Xorg usr/lib/Xorg usr/libexec/Xorg
check_any directory "Xorg module directory" usr/lib/xorg/modules usr/lib64/xorg/modules
check_any directory "Xorg configuration directory" etc/X11

echo
echo "== Mesa userspace =="
check_any file "Mesa/OpenGL library" usr/lib/libGL.so.1 usr/lib64/libGL.so.1 usr/lib/x86_64-linux-gnu/libGL.so.1
check_any file "Mesa EGL library" usr/lib/libEGL.so.1 usr/lib64/libEGL.so.1 usr/lib/x86_64-linux-gnu/libEGL.so.1
check_any file "Mesa GBM library" usr/lib/libgbm.so.1 usr/lib64/libgbm.so.1 usr/lib/x86_64-linux-gnu/libgbm.so.1
check_any directory "Mesa DRI driver directory" usr/lib/dri usr/lib64/dri usr/lib/x86_64-linux-gnu/dri
check_any file "Mesa software rasterizer" usr/lib/dri/swrast_dri.so usr/lib64/dri/swrast_dri.so usr/lib/x86_64-linux-gnu/dri/swrast_dri.so

echo
echo "== Result =="
echo "Present checks: $ok | Required missing checks: $missing"
if (( missing > 0 )); then
  echo "Graphics target is NOT ready for an Xorg + Mesa integration test."
  exit 1
fi
echo "Xorg + Mesa files are present. This does not prove that Xorg starts, GL works, or hardware acceleration is active."
