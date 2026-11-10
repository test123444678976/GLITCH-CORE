#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/config/graphics-sources.lock"
SOURCES="${1:-$ROOT/work-lfs/graphics-sources}"
STAGE_INPUT="${2:-$ROOT/work-lfs/graphics-stage/libdrm}"
BUILD_ROOT="${3:-$ROOT/work-lfs/graphics-build}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires Linux x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Run as an unprivileged build user."
for cmd in tar sha256sum meson ninja; do command -v "$cmd" >/dev/null || fail "Missing tool: $cmd"; done
bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"
entry="$(awk -F'|' '$1=="libdrm"{print; n++} END{if(n!=1)exit 1}' "$LOCK")" || fail "libdrm source pin missing or duplicated."
IFS='|' read -r name version archive url checksum <<< "$entry"
file="$SOURCES/$archive"
[[ -f "$file" && ! -L "$file" ]] || fail "Verified libdrm archive missing: $file"
printf '%s  %s\n' "$checksum" "$file" | sha256sum --check --status || fail "libdrm source checksum mismatch."
for p in "$STAGE_INPUT" "$BUILD_ROOT"; do [[ "$p" == /* && "$p" != "/" ]] || fail "Paths must be absolute and not /."; done
mkdir -p "$STAGE_INPUT" "$BUILD_ROOT"
STAGE="$(realpath -e "$STAGE_INPUT")"; BUILD_ROOT="$(realpath -e "$BUILD_ROOT")"
[[ "$STAGE" != "$BUILD_ROOT" ]] || fail "Stage and build paths must differ."
src="$SOURCES/libdrm-$version"; build="$BUILD_ROOT/libdrm-$version"
[[ -d "$src" ]] || tar -xf "$file" -C "$SOURCES"
[[ -f "$src/meson.build" ]] || fail "libdrm Meson project missing."
meson setup "$build" "$src" --prefix=/usr --libdir=lib --buildtype=release -Dtests=false
ninja -C "$build"
DESTDIR="$STAGE" ninja -C "$build" install
if ! find "$STAGE" -type f -name 'libdrm.so*' -print -quit 2>/dev/null | grep -q .; then
  fail "No libdrm shared library was staged."
fi
mkdir -p "$STAGE/usr/share/glitch-core"
printf 'package=libdrm\nversion=%s\nsource_sha256=%s\ninstall_mode=DESTDIR\n' "$version" "$checksum" > "$STAGE/usr/share/glitch-core/libdrm-build-info"
find "$STAGE" -type f -print | sort > "$STAGE/installed-files.txt"
echo "libdrm $version compiled and staged in $STAGE; not installed into an LFS rootfs."
