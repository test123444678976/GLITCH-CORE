#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_INPUT="${1:-$ROOT/work-lfs/package-manager-stage}"
fail(){ echo "ERROR: $*" >&2; exit 1; }

[[ "$BASE_INPUT" == /* && -d "$BASE_INPUT" ]] || fail "Stage base must be an existing absolute directory."
BASE="$(realpath -e "$BASE_INPUT")"
DPKG="$BASE/dpkg"
APT="$BASE/apt"

[[ -d "$DPKG" && ! -L "$DPKG" && -d "$APT" && ! -L "$APT" ]] ||
  fail "Both dpkg and apt staging directories must exist as real directories."
command -v file >/dev/null 2>&1 || fail "file is required for ELF architecture checks."
command -v realpath >/dev/null 2>&1 || fail "realpath is required for manifest containment checks."

check_executable(){
  local stage="$1" binary="$2" info="$3" package="$4"
  local path="$stage/usr/bin/$binary"
  [[ -f "$path" && -x "$path" && ! -L "$path" ]] || fail "Missing regular staged executable: $path"
  local description
  description="$(file -b "$path")"
  [[ "$description" == *"ELF 64-bit"* && "$description" == *"x86-64"* ]] ||
    fail "$path is not an x86_64 ELF executable: $description"
  echo "[ OK ] $binary — $description"
  local metadata="$stage/usr/share/glitch-core/$info"
  [[ -s "$metadata" ]] || fail "Missing build provenance: $metadata"
  grep -Fxq "package=$package" "$metadata" || fail "Wrong package identity in $info"
  grep -Eq '^version=[0-9][A-Za-z0-9.+:~_-]*$' "$metadata" ||
    fail "Invalid version metadata in $info"
  grep -Eq '^source_sha256=[0-9a-f]{64}$' "$metadata" ||
    fail "Missing source checksum provenance in $info"
  grep -Fxq 'install_mode=DESTDIR' "$metadata" ||
    fail "$info does not record isolated DESTDIR staging."
}

audit_manifest(){
  local stage="$1" manifest="$1/installed-files.txt"
  [[ -s "$manifest" && -f "$manifest" && ! -L "$manifest" ]] ||
    fail "Missing or unsafe installed-files manifest in $stage"
  local path resolved
  local -A seen=()
  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ -n "$path" ]] || fail "Empty entry in $manifest"
    [[ "$path" == ./* && "$path" != *"/../"* && "$path" != */.. ]] || fail "Manifest entry must be a normalized relative path: $path"
    [[ -z "${seen[$path]+x}" ]] || fail "Duplicate manifest entry: $path"
    seen["$path"]=1
    [[ -f "$stage/$path" && ! -L "$stage/$path" ]] || fail "Manifest entry is not a regular staged file: $path"
    resolved="$(realpath -e "$stage/$path")"
    case "$resolved" in
      "$stage"/*) ;;
      *) fail "Resolved manifest entry escapes its staging tree: $path -> $resolved" ;;
    esac
  done < "$manifest"

}

echo "GLITCH//CORE — native package-manager staging audit"
check_executable "$DPKG" dpkg dpkg-build-info dpkg
check_executable "$DPKG" dpkg-deb dpkg-build-info dpkg
check_executable "$DPKG" dpkg-query dpkg-build-info dpkg
check_executable "$APT" apt-get apt-build-info apt
check_executable "$APT" apt-cache apt-build-info apt

audit_manifest "$DPKG"
audit_manifest "$APT"

for required in ./usr/bin/dpkg ./usr/bin/dpkg-deb ./usr/bin/dpkg-query ./usr/share/glitch-core/dpkg-build-info; do
  grep -Fxq "$required" "$DPKG/installed-files.txt" || fail "dpkg manifest omits required output: $required"
done
for required in ./usr/bin/apt-get ./usr/bin/apt-cache ./usr/share/glitch-core/apt-build-info; do
  grep -Fxq "$required" "$APT/installed-files.txt" || fail "APT manifest omits required output: $required"
done

echo "Native dpkg/APT staging audit: PASSED"
echo "Executables, architecture, provenance, manifest membership and resolved paths are valid."
echo "This does not yet prove compatibility inside the LFS target rootfs."
