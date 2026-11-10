#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail(){ echo "ERROR: $*" >&2; exit 1; }
for script in validate-package-manager-sources.sh fetch-package-manager-sources.sh build-dpkg.sh build-apt.sh; do
  bash -n "$ROOT/scripts/lfs/$script" || fail "Shell syntax failed: $script"
done
bash "$ROOT/scripts/lfs/validate-package-manager-sources.sh"
grep -q 'dpkg|1.23.11|dpkg_1.23.11.tar.xz' "$ROOT/config/package-manager-sources.lock" || fail "dpkg source pin missing."
grep -q 'apt|3.0.4|apt_3.0.4.tar.xz' "$ROOT/config/package-manager-sources.lock" || fail "APT source pin missing."
for script in build-dpkg.sh build-apt.sh; do
  grep -q 'DESTDIR=' "$ROOT/scripts/lfs/$script" || fail "$script must stage, not install directly."
  grep -q 'sha256sum --check --status' "$ROOT/scripts/lfs/$script" || fail "$script must verify its source."
  grep -q 'id -u' "$ROOT/scripts/lfs/$script" || fail "$script must refuse root execution."
done
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp "$ROOT/config/package-manager-sources.lock" "$tmp/lock"
sed -i '/^apt|/d' "$tmp/lock"
if bash "$ROOT/scripts/lfs/validate-package-manager-sources.sh" "$tmp/lock" >/dev/null 2>&1; then fail "Accepted incomplete dpkg/APT source lock."; fi
echo "Native dpkg/APT source and build-pipeline tests: OK"
