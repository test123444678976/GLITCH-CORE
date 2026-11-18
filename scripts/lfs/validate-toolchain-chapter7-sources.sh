#!/usr/bin/env bash
set -Eeuo pipefail

# Verify that every LFS 13.1-systemd Chapter 7 temporary-tool archive is
# present in the official manifests and matches its recorded MD5 checksum.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/config/lfs-toolchain.lock"
SOURCES="$ROOT/work-lfs/lfs/sources"
if [[ $# -gt 0 ]]; then SOURCES="$1"; fi

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -d "$SOURCES" && ! -L "$SOURCES" ]] || fail "LFS sources directory is missing or unsafe."
for manifest in wget-list md5sums; do
  [[ -s "$SOURCES/$manifest" && ! -L "$SOURCES/$manifest" ]] || fail "Official LFS source manifest is missing: $manifest"
done

packages="$(awk -F= '$1 == "CHAPTER7_TEMPORARY_PACKAGES" { sub(/^[^=]*=/, ""); print; count++ } END { if (count != 1) exit 1 }' "$LOCK")" \
  || fail "Chapter 7 temporary package contract is missing or duplicated."
IFS=',' read -r -a archives <<< "$packages"
[[ "${#archives[@]}" -eq 8 ]] || fail "Expected exactly eight Chapter 7 temporary-tool archives."

declare -A seen=()
for archive in "${archives[@]}"; do
  [[ "$archive" =~ ^[A-Za-z0-9._+-]+\.tar\.(xz|gz|bz2)$ ]] || fail "Unsafe Chapter 7 archive name: $archive"
  [[ -z "${seen[$archive]+present}" ]] || fail "Duplicate Chapter 7 archive in source contract: $archive"
  seen["$archive"]=1

  url_count="$(awk -v expected="$archive" '
    {
      url = $0
      sub(/[?#].*$/, "", url)
      sub(/^.*\//, "", url)
      if (url == expected) count++
    }
    END { print count + 0 }
  ' "$SOURCES/wget-list")"
  [[ "$url_count" -eq 1 ]] || fail "Expected exactly one official download URL for $archive; found $url_count."

  expected_md5="$(awk -v expected="$archive" '$2 == expected { print $1; count++ } END { if (count != 1) exit 1 }' "$SOURCES/md5sums")" \
    || fail "Expected exactly one official MD5 entry for $archive."
  [[ "$expected_md5" =~ ^[[:xdigit:]]{32}$ ]] || fail "Invalid MD5 entry for $archive."

  file="$SOURCES/$archive"
  [[ -f "$file" && ! -L "$file" ]] || fail "Verified Chapter 7 source archive is missing or unsafe: $archive"
  actual_md5="$(md5sum -- "$file" | awk '{print $1}')"
  [[ "$actual_md5" == "$expected_md5" ]] || fail "Chapter 7 source checksum mismatch: $archive"
  echo "[ OK ] $archive"
done

echo "LFS 13.1 Chapter 7 temporary-tool source contract: OK"
