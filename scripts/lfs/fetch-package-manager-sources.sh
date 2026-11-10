#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/package-manager-sources.lock}"
DEST_INPUT="${2:-$ROOT/work-lfs/package-manager-sources}"
FILTER="${3:-}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
command -v curl >/dev/null || fail "curl is required."
command -v sha256sum >/dev/null || fail "sha256sum is required."
bash "$ROOT/scripts/lfs/validate-package-manager-sources.sh" "$LOCK"
if [[ -n "$FILTER" && ! "$FILTER" =~ ^(dpkg|apt)$ ]]; then fail "Filter must be dpkg or apt."; fi
mkdir -p "$DEST_INPUT"; DEST="$(realpath -e "$DEST_INPUT")"
[[ "$DEST" != "/" && -w "$DEST" ]] || fail "Unsafe or unwritable destination."
tmp="$(mktemp -d "$DEST/.pkg-download.XXXXXX")"; trap 'rm -rf "$tmp"' EXIT
selected=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"; [[ -z "${line//[[:space:]]/}" ]] && continue
  IFS='|' read -r name version archive url checksum <<< "$line"
  [[ -z "$FILTER" || "$FILTER" == "$name" ]] || continue
  selected=$((selected+1)); final="$DEST/$archive"
  if [[ -f "$final" && ! -L "$final" ]] && printf '%s  %s\n' "$checksum" "$final" | sha256sum --check --status; then
    echo "[OK] $name $version already verified."; continue
  fi
  [[ ! -e "$final" && ! -L "$final" ]] || fail "Refusing unsafe existing path: $final"
  partial="$tmp/$archive.part"
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 --output "$partial" "$url"
  printf '%s  %s\n' "$checksum" "$partial" | sha256sum --check --status || fail "Checksum mismatch for $archive."
  mv "$partial" "$final"; echo "[OK] $archive verified."
done < "$LOCK"
(( selected > 0 )) || fail "No package matched filter '$FILTER'."
