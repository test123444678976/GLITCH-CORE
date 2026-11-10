#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="${1:-$ROOT/config/graphics-sources.lock}"
DEST_INPUT="${2:-$ROOT/work-lfs/graphics-sources}"
fail() { echo "ERROR: $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required."
bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"

mkdir -p "$DEST_INPUT"
DEST="$(realpath -e "$DEST_INPUT")"
[[ "$DEST" != "/" ]] || fail "Refusing to use the filesystem root as the download directory."
[[ -w "$DEST" ]] || fail "Download directory is not writable: $DEST"

tmpdir="$(mktemp -d "$DEST/.graphics-download.XXXXXX")"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  IFS='|' read -r name version archive url checksum <<< "$line"
  final="$DEST/$archive"

  if [[ -f "$final" ]]; then
    if printf '%s  %s\n' "$checksum" "$final" | sha256sum --check --status; then
      echo "[ OK ] $name $version already downloaded and verified."
      continue
    fi
    echo "[WARN] Existing archive has the wrong checksum; replacing it: $archive"
  elif [[ -e "$final" ]]; then
    fail "Refusing to replace a non-regular archive path: $final"
  fi

  echo "==> Downloading $name $version"
  partial="$tmpdir/$archive.part"
  curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    --output "$partial" "$url"

  printf '%s  %s\n' "$checksum" "$partial" | sha256sum --check --status ||
    fail "SHA-256 verification failed for $archive"

  mv -f "$partial" "$final"
  echo "[ OK ] $archive verified and stored."
done < "$LOCK"

echo
echo "Verified graphics source archives are in: $DEST"
echo "Only the entries in the partial lock were downloaded; no compilation was performed."
