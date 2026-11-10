#!/usr/bin/env bash
set -Eeuo pipefail

# Native x86_64 CI build of the X.Org transport headers.
# This DESTDIR output is a host-side checkpoint, not an LFS target install.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/graphics-sources.lock}"
SOURCES="${2:-$ROOT/work-lfs/graphics-sources}"
STAGE_INPUT="${3:-$ROOT/work-lfs/graphics-stage/xtrans}"
BUILD_ROOT="${4:-$ROOT/work-lfs/graphics-build}"
fail() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires a Linux x86_64 build host."
[[ "$(id -u)" -ne 0 ]] || fail "Run as an unprivileged build user."
for cmd in bash tar sha256sum make; do command -v "$cmd" >/dev/null 2>&1 || fail "Missing build tool: $cmd"; done
bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"
entry="$(awk -F'|' '$1=="xtrans"{print; n++} END{if(n!=1)exit 1}' "$LOCK")" || fail "The lock must contain exactly one xtrans entry."
IFS='|' read -r name version archive url checksum <<< "$entry"
[[ "$version" == "1.6.0" ]] || fail "Unexpected xtrans version: $version"
source_archive="$SOURCES/$archive"
[[ -f "$source_archive" && ! -L "$source_archive" ]] || fail "Verified source archive missing: $source_archive"
printf '%s  %s\n' "$checksum" "$source_archive" | sha256sum --check --status || fail "xtrans source checksum mismatch."

for path in "$STAGE_INPUT" "$BUILD_ROOT"; do [[ "$path" == /* && "$path" != "/" ]] || fail "Build and stage paths must be absolute and not /."; done
mkdir -p "$SOURCES" "$STAGE_INPUT" "$BUILD_ROOT"
SOURCES="$(realpath -e "$SOURCES")"
STAGE="$(realpath -e "$STAGE_INPUT")"
BUILD_ROOT="$(realpath -e "$BUILD_ROOT")"
[[ "$STAGE" != "$SOURCES" && "$STAGE" != "$BUILD_ROOT" ]] || fail "Source, build and stage paths must be separate."
src="$SOURCES/xtrans-$version"
build="$BUILD_ROOT/xtrans-$version"
if [[ ! -d "$src" ]]; then
  log "Extracting xtrans $version"
  tar -xf "$source_archive" -C "$SOURCES"
fi
[[ -x "$src/configure" ]] || fail "Expected xtrans configure script is missing."
mkdir -p "$build"
log "Configuring xtrans $version"
cd "$build"
"$src/configure" --prefix=/usr --libdir=/usr/lib
log "Building xtrans"
make -j"${JOBS:-2}"
log "Staging xtrans with DESTDIR"
make DESTDIR="$STAGE" install
[[ -d "$STAGE/usr/include/X11/Xtrans" ]] || fail "Xtrans headers were not staged."
[[ -d "$STAGE/usr/share/aclocal" || -d "$STAGE/usr/lib/pkgconfig" ]] || fail "Expected xtrans build metadata was not staged."
find "$STAGE" -type f -print | sort > "$STAGE/installed-files.txt"
cat > "$STAGE/BUILD-INFO.txt" <<EOF
GLITCH//CORE graphics component build
Package: xtrans
Version: $version
Archive: $archive
SHA256: $checksum
Build system: Autotools + Make
Install mode: DESTDIR staging (not installed into an LFS root filesystem)
Build host architecture: x86_64
EOF
log "xtrans build completed"
echo "Staging tree: $STAGE"
echo "Installed files: $(wc -l < "$STAGE/installed-files.txt")"
echo "This is a host-side build checkpoint, not an LFS target installation."
