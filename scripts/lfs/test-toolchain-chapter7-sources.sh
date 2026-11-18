#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/lfs/validate-toolchain-chapter7-sources.sh"
LOCK="$ROOT/config/lfs-toolchain.lock"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$VALIDATOR" || fail "Chapter 7 source validator has invalid Bash syntax."
packages="$(awk -F= '$1 == "CHAPTER7_TEMPORARY_PACKAGES" { sub(/^[^=]*=/, ""); print; count++ } END { if (count != 1) exit 1 }' "$LOCK")" \
  || fail "Chapter 7 package list is missing or duplicated."
IFS=',' read -r -a archives <<< "$packages"
[[ "${#archives[@]}" -eq 8 ]] || fail "Chapter 7 source contract must contain eight archives."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/sources"
mkdir -p "$fixture"

for archive in "${archives[@]}"; do
  printf 'fixture source for %s\n' "$archive" > "$fixture/$archive"
  printf 'https://example.invalid/lfs/%s\n' "$archive" >> "$fixture/wget-list"
  (cd "$fixture" && md5sum -- "$archive") >> "$fixture/md5sums"
done

bash "$VALIDATOR" "$fixture" >/dev/null || fail "Valid Chapter 7 source fixture was rejected."

missing="$tmp/missing"
cp -a "$fixture" "$missing"
rm -- "$missing/${archives[0]}"
if bash "$VALIDATOR" "$missing" >/dev/null 2>&1; then
  fail "Validator accepted a missing Chapter 7 archive."
fi

bad_checksum="$tmp/bad-checksum"
cp -a "$fixture" "$bad_checksum"
printf 'tampered source\n' > "$bad_checksum/${archives[1]}"
if bash "$VALIDATOR" "$bad_checksum" >/dev/null 2>&1; then
  fail "Validator accepted a Chapter 7 archive with a mismatched checksum."
fi

duplicate_url="$tmp/duplicate-url"
cp -a "$fixture" "$duplicate_url"
printf 'https://example.invalid/duplicate/%s\n' "${archives[2]}" >> "$duplicate_url/wget-list"
if bash "$VALIDATOR" "$duplicate_url" >/dev/null 2>&1; then
  fail "Validator accepted a duplicated Chapter 7 download URL."
fi

duplicate_md5="$tmp/duplicate-md5"
cp -a "$fixture" "$duplicate_md5"
awk -v name="${archives[3]}" '$2 == name { print; found=1 } END { if (!found) exit 1 }' "$fixture/md5sums" >> "$duplicate_md5/md5sums"
if bash "$VALIDATOR" "$duplicate_md5" >/dev/null 2>&1; then
  fail "Validator accepted a duplicated Chapter 7 checksum entry."
fi

echo "LFS Chapter 7 temporary-tool source validation tests: OK"
