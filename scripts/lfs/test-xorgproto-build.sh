#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FETCH="$ROOT/scripts/lfs/fetch-graphics-sources.sh"
BUILD="$ROOT/scripts/lfs/build-xorgproto.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$FETCH"
bash -n "$BUILD"
grep -q 'PACKAGE_FILTER="${3:-}"' "$FETCH" || fail "Source fetcher lacks package filtering."
grep -q 'sha256sum --check --status' "$BUILD" || fail "xorgproto builder does not verify SHA-256."
grep -q 'meson setup' "$BUILD" || fail "xorgproto builder does not configure Meson."
grep -q 'ninja -C' "$BUILD" || fail "xorgproto builder does not compile with Ninja."
grep -q 'DESTDIR="$STAGE"' "$BUILD" || fail "xorgproto builder does not isolate installation in DESTDIR."
grep -q 'id -u' "$BUILD" || fail "xorgproto builder does not reject root execution."
grep -q 'xorgproto' "$ROOT/config/graphics-sources.lock" || fail "xorgproto is not pinned in the graphics source lock."

echo "xorgproto build pipeline checks: OK"
echo "NOTE: these checks inspect build safeguards; the separate build workflow compiles the component."
