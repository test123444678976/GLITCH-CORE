#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/lfs/install-package-manager-config.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
bash -n "$SCRIPT"
mkdir -p "$TMP/target/etc" "$TMP/target/usr/bin"
for bin in dpkg dpkg-deb apt-get apt-cache; do printf '#!/bin/sh\nexit 0\n' > "$TMP/target/usr/bin/$bin"; chmod +x "$TMP/target/usr/bin/$bin"; done
bash "$SCRIPT" "$TMP/target"
[[ -s "$TMP/target/etc/apt/apt.conf" ]]
[[ -s "$TMP/target/etc/apt/sources.list" ]]
[[ -f "$TMP/target/var/lib/dpkg/status" ]]
[[ -d "$TMP/target/var/lib/apt/lists/partial" ]]
if bash "$SCRIPT" "$TMP" >/dev/null 2>&1; then echo "ERROR: unsafe target accepted." >&2; exit 1; fi
echo "APT/dpkg target configuration tests: OK"
