#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/scripts/lfs/build-xtrans.sh"
LOCK="$ROOT/config/graphics-sources.lock"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$BUILD"
bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"
grep -q '^xtrans|1.6.0|xtrans-1.6.0.tar.xz|https://xorg.freedesktop.org/archive/individual/lib/xtrans-1.6.0.tar.xz|faafea166bf2451a173d9d593352940ec6404145c5d1da5c213423ce4d359e92$' "$LOCK" ||
  fail "xtrans 1.6.0 source pin is missing or changed."
grep -q 'sha256sum --check --status' "$BUILD" || fail "Builder does not verify SHA-256."
grep -q 'DESTDIR="$STAGE"' "$BUILD" || fail "Builder does not use isolated DESTDIR staging."
grep -q 'id -u' "$BUILD" || fail "Builder does not reject root execution."
grep -q 'version" == "1.6.0' "$BUILD" || fail "Builder does not pin the expected xtrans release."
grep -q 'not an LFS target installation' "$BUILD" || fail "Builder does not distinguish host staging from target installation."

echo "xtrans build pipeline checks: OK"
echo "NOTE: this test checks build safeguards; the CI build performs compilation."
