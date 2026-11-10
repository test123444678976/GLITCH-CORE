#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/package-manager-sources.lock}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ -s "$LOCK" ]] || fail "Package-manager source lock missing."
declare -A names=() archives=()
count=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  IFS='|' read -r name version archive url checksum extra <<< "$line"
  [[ -n "$name" && -n "$version" && -n "$archive" && -n "$url" && -n "$checksum" && -z "${extra:-}" ]] || fail "Expected five fields: $raw"
  [[ "$name" =~ ^(dpkg|apt)$ ]] || fail "Package not permitted in this initial lock: $name"
  [[ "$version" =~ ^[0-9][A-Za-z0-9.+_-]*$ ]] || fail "Invalid version: $version"
  [[ "$archive" == "$(basename "$archive")" && "$archive" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*\.tar\.(xz|gz|bz2)$ ]] || fail "Invalid archive: $archive"
  [[ "$url" == https://deb.debian.org/debian/pool/main/* ]] || fail "Only the official source archive host/path is permitted."
  [[ "${url##*/}" == "$archive" ]] || fail "URL/archive mismatch for $name."
  [[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || fail "Invalid SHA-256 for $name."
  [[ -z "${names[$name]+x}" && -z "${archives[$archive]+x}" ]] || fail "Duplicate package or archive."
  names["$name"]=1; archives["$archive"]=1; count=$((count+1))
done < "$LOCK"
(( count == 2 )) || fail "Expected exactly dpkg and apt source pins."
echo "Native package-manager source lock: OK ($count verified upstream source pins)"
