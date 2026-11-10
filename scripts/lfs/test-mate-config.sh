#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash "$ROOT/scripts/lfs/validate-mate-stack.sh"

for file in \
  "$ROOT/config/lightdm/lightdm.conf" \
  "$ROOT/config/xsessions/mate.desktop" \
  "$ROOT/scripts/lfs/install-mate-config.sh" \
  "$ROOT/config/mate-build-order.txt"; do
  [[ -s "$file" ]] || fail "Missing or empty integration file: $file"
done

grep -Eq '^user-session=mate$' "$ROOT/config/lightdm/lightdm.conf" ||
  fail "LightDM is not configured to start the MATE session."
grep -Eq '^Exec=mate-session$' "$ROOT/config/xsessions/mate.desktop" ||
  fail "MATE session desktop entry is invalid."
grep -q 'systemctl --root=.* enable lightdm.service' "$ROOT/scripts/lfs/install-mate-config.sh" ||
  fail "LightDM is not enabled in the target system."
bash -n "$ROOT/scripts/lfs/install-mate-config.sh"

echo "MATE integration configuration: OK"
echo "NOTE: these checks do not compile MATE or create a desktop ISO."
