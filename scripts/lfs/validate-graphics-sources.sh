#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/graphics-sources.lock}"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -s "$LOCK" ]] || fail "Graphics source lock is missing or empty: $LOCK"

declare -A names=() archives=()
count=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  IFS='|' read -r name version archive url checksum extra <<< "$line"
  [[ -n "$name" && -n "$version" && -n "$archive" && -n "$url" && -n "$checksum" && -z "${extra:-}" ]] ||
    fail "Expected exactly five pipe-separated fields: $raw"
  [[ "$name" =~ ^[a-z0-9][a-z0-9+_.-]*$ ]] || fail "Invalid package name: $name"
  [[ "$version" =~ ^[0-9][A-Za-z0-9.+_-]*$ ]] || fail "Invalid version for $name: $version"
  [[ "$archive" == "$(basename "$archive")" && "$archive" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*\.tar\.(xz|gz|bz2)$ ]] ||
    fail "Invalid archive filename for $name: $archive"
  [[ "$url" == https://* ]] || fail "Only HTTPS source URLs are accepted: $url"
  case "$url" in
    https://archive.mesa3d.org/*|https://dri.freedesktop.org/*|https://xorg.freedesktop.org/*) ;;
    *) fail "Source host is not in the approved upstream allowlist: $url" ;;
  esac
  [[ "${url##*/}" == "$archive" ]] || fail "URL basename does not match archive for $name."
  [[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || fail "Invalid SHA-256 for $name."
  [[ -z "${names[$name]+x}" ]] || fail "Duplicate package name: $name"
  [[ -z "${archives[$archive]+x}" ]] || fail "Duplicate archive filename: $archive"
  names["$name"]=1
  archives["$archive"]=1
  count=$((count + 1))
done < "$LOCK"

(( count > 0 )) || fail "No source entries found in $LOCK"
echo "Graphics source lock: OK ($count pinned archives)"
echo "Note: this lock is a partial subset, not the complete graphics stack."
