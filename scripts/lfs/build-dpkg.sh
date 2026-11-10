#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/config/package-manager-sources.lock"
SOURCES="${1:-$ROOT/work-lfs/package-manager-sources}"
STAGE_INPUT="${2:-$ROOT/work-lfs/package-manager-stage/dpkg}"
BUILD_ROOT="${3:-$ROOT/work-lfs/package-manager-build}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires Linux x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Run as an unprivileged build user."
for cmd in tar sha256sum make gcc; do command -v "$cmd" >/dev/null || fail "Missing tool: $cmd"; done
bash "$ROOT/scripts/lfs/validate-package-manager-sources.sh" "$LOCK"
entry="$(awk -F'|' '$1=="dpkg"{print; n++} END{if(n!=1)exit 1}' "$LOCK")" || fail "dpkg source pin missing or duplicated."
IFS='|' read -r name version archive url checksum <<< "$entry"
file="$SOURCES/$archive"
[[ -f "$file" && ! -L "$file" ]] || fail "Verified source archive missing: $file"
printf '%s  %s\n' "$checksum" "$file" | sha256sum --check --status || fail "dpkg source checksum mismatch."
for p in "$STAGE_INPUT" "$BUILD_ROOT"; do [[ "$p" == /* && "$p" != "/" ]] || fail "Paths must be absolute and not /."; done
mkdir -p "$STAGE_INPUT" "$BUILD_ROOT"
STAGE="$(realpath -e "$STAGE_INPUT")"; BUILD_ROOT="$(realpath -e "$BUILD_ROOT")"
[[ "$STAGE" != "$BUILD_ROOT" ]] || fail "Stage and build paths must differ."
src="$SOURCES/dpkg-$version"; build="$BUILD_ROOT/dpkg-$version"
[[ -d "$src" ]] || tar -xf "$file" -C "$SOURCES"
[[ -x "$src/configure" ]] || fail "dpkg configure script missing."
mkdir -p "$build"
cd "$build"
"$src/configure" --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-nls
make -j"${JOBS:-2}"
make DESTDIR="$STAGE" install
for bin in dpkg dpkg-deb dpkg-query; do [[ -x "$STAGE/usr/bin/$bin" ]] || fail "Missing staged executable: $bin"; done
mkdir -p "$STAGE/usr/share/glitch-core"
printf 'package=dpkg\nversion=%s\nsource_sha256=%s\ninstall_mode=DESTDIR\n' "$version" "$checksum" > "$STAGE/usr/share/glitch-core/dpkg-build-info"
(cd "$STAGE" && find . -type f -print | LC_ALL=C sort > installed-files.txt)
echo "dpkg $version compiled and staged in $STAGE; not installed into an LFS rootfs."
