#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/lfs/validate-package-manager.sh"
MANIFEST="$ROOT/config/package-manager.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== Positive package-manager manifest test =="
bash "$VALIDATOR" "$MANIFEST"

echo
echo "== Negative package-manager manifest test =="
cp "$MANIFEST" "$TMP/broken-manifest.txt"
sed -i '/^apt$/d' "$TMP/broken-manifest.txt"
if bash "$VALIDATOR" "$TMP/broken-manifest.txt" >/dev/null 2>&1; then
  echo "ERROR: validator accepted a manifest without the apt target." >&2
  exit 1
fi
echo "Invalid manifest correctly rejected."

echo
echo "== Repository safety policy test =="
if grep -Eiq 'deb\\s+.*(debian.org|ubuntu.com)|archive.ubuntu.com|deb.debian.org' "$MANIFEST"; then
  echo "ERROR: foreign Debian/Ubuntu repository detected in native package plan." >&2
  exit 1
fi
echo "No Debian/Ubuntu repository configured as a GLITCH//CORE source."
echo
echo "Package-manager integration tests passed."
