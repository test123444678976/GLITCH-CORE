#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="${1:-$ROOT/work-lfs/package-manager-stage}"
DPKG="$BASE/dpkg"
APT="$BASE/apt"
fail(){ echo "ERROR: $*" >&2; exit 1; }

[[ -d "$DPKG" && -d "$APT" ]] || fail "Both dpkg and apt staging directories are required."
command -v file >/dev/null 2>&1 || fail "file is required for ELF architecture checks."

check_executable(){
  local stage="$1" binary="$2" info="$3"
  local path="$stage/usr/bin/$binary"
  [[ -f "$path" && -x "$path" ]] || fail "Missing staged executable: $path"
  local description
  description="$(file -b "$path")"
  [[ "$description" == *"ELF 64-bit"* && "$description" == *"x86-64"* ]] ||
    fail "$path is not an x86_64 ELF executable: $description"
  echo "[ OK ] $binary — $description"
  [[ -s "$stage/usr/share/glitch-core/$info" ]] || fail "Missing build provenance: $info"
  grep -Eq '^version=[0-9][A-Za-z0-9.+:~_-]*$' "$stage/usr/share/glitch-core/$info" ||
    fail "Invalid version metadata in $info"
  grep -Eq '^source_sha256=[0-9a-f]{64}$' "$stage/usr/share/glitch-core/$info" ||
    fail "Missing source checksum provenance in $info"
  grep -Fxq 'install_mode=DESTDIR' "$stage/usr/share/glitch-core/$info" ||
    fail "$info does not record isolated DESTDIR staging."
}

echo "GLITCH//CORE — native package-manager staging audit"
check_executable "$DPKG" dpkg dpkg-build-info
check_executable "$DPKG" dpkg-deb dpkg-build-info
check_executable "$DPKG" dpkg-query dpkg-build-info
check_executable "$APT" apt-get apt-build-info
check_executable "$APT" apt-cache apt-build-info

for stage in "$DPKG" "$APT"; do
  [[ -s "$stage/installed-files.txt" ]] || fail "Missing installed-files manifest in $stage"
  while IFS= read -r path; do
    [[ -n "$path" && -e "$path" ]] || fail "Manifest entry is missing: $path"
    case "$path" in "$stage"/*) ;; *) fail "Manifest path escapes its staging tree: $path" ;; esac
  done < "$stage/installed-files.txt"
done

echo "Native dpkg/APT staging audit: PASSED"
echo "Both projects produced x86_64 executables with source provenance and isolated install manifests."
echo "This does not yet prove compatibility inside the LFS target rootfs."
