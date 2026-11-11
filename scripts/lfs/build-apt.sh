#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/config/package-manager-sources.lock"
SOURCES="${1:-$ROOT/work-lfs/package-manager-sources}"
STAGE_INPUT="${2:-$ROOT/work-lfs/package-manager-stage/apt}"
BUILD_ROOT="${3:-$ROOT/work-lfs/package-manager-build}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires Linux x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Run as an unprivileged build user."
for cmd in tar sha256sum cmake ninja c++ pkg-config; do command -v "$cmd" >/dev/null || fail "Missing tool: $cmd"; done
bash "$ROOT/scripts/lfs/validate-package-manager-sources.sh" "$LOCK"
entry="$(awk -F'|' '$1=="apt"{print; n++} END{if(n!=1)exit 1}' "$LOCK")" || fail "APT source pin missing or duplicated."
IFS='|' read -r name version archive url checksum <<< "$entry"
file="$SOURCES/$archive"
[[ -f "$file" && ! -L "$file" ]] || fail "Verified source archive missing: $file"
printf '%s  %s\n' "$checksum" "$file" | sha256sum --check --status || fail "APT source checksum mismatch."
for p in "$STAGE_INPUT" "$BUILD_ROOT"; do [[ "$p" == /* && "$p" != "/" ]] || fail "Paths must be absolute and not /."; done
mkdir -p "$STAGE_INPUT" "$BUILD_ROOT"
STAGE="$(realpath -e "$STAGE_INPUT")"; BUILD_ROOT="$(realpath -e "$BUILD_ROOT")"
[[ "$STAGE" != "$BUILD_ROOT" ]] || fail "Stage and build paths must differ."
src="$SOURCES/apt-$version"; build="$BUILD_ROOT/apt-$version"
# Always unpack the checksum-verified archive into a fresh source tree.
# Never trust a pre-existing extracted directory from an earlier or external run.
[[ ! -L "$src" ]] || fail "Refusing symlinked apt source tree: $src"
rm -rf -- "$src"
tar -xf "$file" -C "$SOURCES"
[[ -d "$src" && ! -L "$src" ]] || fail "Expected apt source directory was not extracted: $src"
# Reconfigure from scratch so stale Make/CMake caches cannot affect the build.
[[ ! -L "$build" ]] || fail "Refusing symlinked apt build directory: $build"
rm -rf -- "$build"
mkdir -p "$build"
[[ -f "$src/CMakeLists.txt" ]] || fail "APT CMakeLists.txt missing."
cmake -S "$src" -B "$build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_SYSCONFDIR=/etc \
  -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
  -DWITH_DOC=OFF -DWITH_TESTS=OFF -DUSE_NLS=OFF
cmake --build "$build" --parallel "${JOBS:-2}"
DESTDIR="$STAGE" cmake --install "$build"
[[ -x "$STAGE/usr/bin/apt-get" ]] || fail "apt-get was not staged."
[[ -x "$STAGE/usr/bin/apt-cache" ]] || fail "apt-cache was not staged."
mkdir -p "$STAGE/usr/share/glitch-core"
printf 'package=apt\nversion=%s\nsource_sha256=%s\ninstall_mode=DESTDIR\n' "$version" "$checksum" > "$STAGE/usr/share/glitch-core/apt-build-info"
(cd "$STAGE" && find . -type f -print | LC_ALL=C sort > installed-files.txt)
echo "APT $version compiled and staged in $STAGE; not installed into an LFS rootfs."
