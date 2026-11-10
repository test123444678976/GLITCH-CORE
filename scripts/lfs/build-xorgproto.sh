#!/usr/bin/env bash
set -Eeuo pipefail

# Build the first independently pinned X.Org protocol component.
# This is a native x86_64 build into a DESTDIR staging tree, not a full LFS build.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/graphics-sources.lock}"
SOURCES="${2:-$ROOT/work-lfs/graphics-sources}"
STAGE_INPUT="${3:-$ROOT/work-lfs/graphics-stage/xorgproto}"
BUILD_ROOT="${4:-$ROOT/work-lfs/graphics-build}"
fail() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

[[ "$(uname -s)" == Linux ]] || fail "A Linux build host is required."
[[ "$(uname -m)" == x86_64 ]] || fail "This build currently targets x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Run as an unprivileged build user, not root."
for cmd in bash tar sha256sum meson ninja; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing build tool: $cmd"
done
bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"

entry="$(awk -F'|' '$1 == "xorgproto" {print; found++} END {if (found != 1) exit 1}' "$LOCK")" ||
  fail "The lock must contain exactly one xorgproto entry."
IFS='|' read -r name version archive url checksum <<< "$entry"
[[ "$version" == "2026.1" ]] || fail "Unexpected xorgproto version: $version"
source_archive="$SOURCES/$archive"
[[ -f "$source_archive" && ! -L "$source_archive" ]] || fail "Verified archive not found: $source_archive"
printf '%s  %s\n' "$checksum" "$source_archive" | sha256sum --check --status ||
  fail "Archive checksum mismatch: $archive"

for path in "$STAGE_INPUT" "$BUILD_ROOT"; do
  [[ "$path" == /* && "$path" != "/" ]] || fail "Build and staging paths must be absolute and not /."
done
mkdir -p "$SOURCES" "$STAGE_INPUT" "$BUILD_ROOT"
SOURCES="$(realpath -e "$SOURCES")"
STAGE="$(mkdir -p "$STAGE_INPUT" && realpath -e "$STAGE_INPUT")"
BUILD_ROOT="$(realpath -e "$BUILD_ROOT")"
[[ "$STAGE" != "$SOURCES" && "$STAGE" != "$BUILD_ROOT" ]] || fail "Source, build and stage paths must be separate."
[[ -w "$STAGE" && -w "$BUILD_ROOT" ]] || fail "Build or staging directory is not writable."

src="$SOURCES/xorgproto-$version"
build="$BUILD_ROOT/xorgproto-$version"
if [[ ! -d "$src" ]]; then
  log "Extracting pinned xorgproto $version"
  tar -xf "$source_archive" -C "$SOURCES"
fi
[[ -f "$src/meson.build" ]] || fail "Expected Meson project not found: $src/meson.build"
mkdir -p "$build"

log "Configuring xorgproto $version"
meson setup "$build" "$src" --prefix=/usr --libdir=lib --buildtype=release

log "Compiling xorgproto"
ninja -C "$build"

log "Installing xorgproto into isolated DESTDIR"
DESTDIR="$STAGE" ninja -C "$build" install

[[ -d "$STAGE/usr/include" ]] || fail "Protocol headers were not staged."
[[ -d "$STAGE/usr/share/pkgconfig" || -d "$STAGE/usr/lib/pkgconfig" || -d "$STAGE/usr/lib/x86_64-linux-gnu/pkgconfig" ]] ||
  fail "No pkg-config metadata was staged."
find "$STAGE" -type f -print | sort > "$STAGE/installed-files.txt"
[[ -s "$STAGE/installed-files.txt" ]] || fail "Installed-file manifest is empty."

cat > "$STAGE/BUILD-INFO.txt" <<EOF
GLITCH//CORE graphics component build
Package: xorgproto
Version: $version
Archive: $archive
SHA256: $checksum
Build system: Meson + Ninja
Install mode: DESTDIR staging (not installed into an LFS root filesystem)
Target architecture: x86_64
EOF

log "xorgproto build completed"
echo "Staging tree: $STAGE"
echo "Installed files: $(wc -l < "$STAGE/installed-files.txt")"
echo "This artifact is a first graphics prerequisite only; it is not Xorg, Mesa, MATE, or a bootable desktop."
