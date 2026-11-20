#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/scripts/lfs/ensure-coreutils-source.sh"
BUILD_SCRIPT="$ROOT/scripts/build-lfs.sh"
ARCHIVE="coreutils-9.11.tar.xz"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$HELPER" || fail "coreutils source fallback helper has invalid Bash syntax."
grep -Fq 'ensure-coreutils-source.sh' "$BUILD_SCRIPT" ||
  fail "The LFS source preparation script must invoke the coreutils fallback helper."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
SOURCES="$tmp/sources"
STUBS="$tmp/stubs"
mkdir -p "$SOURCES" "$STUBS"

payload='GLITCHCORE coreutils source fixture'
printf '%s' "$payload" > "$tmp/fixture.tar.xz"
digest="$(md5sum "$tmp/fixture.tar.xz" | awk '{print $1}')"
printf '%s  %s\n' "$digest" "$ARCHIVE" > "$SOURCES/md5sums"

cat > "$STUBS/wget" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
url=""
while (($#)); do
  case "$1" in
    --output-document=*) output="${1#*=}"; shift ;;
    --output-document|-O) output="${2:?}"; shift 2 ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$output" && -n "$url" ]] || exit 2
printf '%s\n' "$url" >> "$FAKE_WGET_LOG"
case "$url" in
  *mirror-one.invalid/*) exit 8 ;;
  *mirror-two.invalid/*) cp -- "$FAKE_WGET_SOURCE" "$output" ;;
  *mirror-bad.invalid/*) printf 'not the pinned archive\n' > "$output" ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$STUBS/wget"

export PATH="$STUBS:$PATH"
export FAKE_WGET_LOG="$tmp/wget.log"
export FAKE_WGET_SOURCE="$tmp/fixture.tar.xz"
export COREUTILS_MIRROR_URLS=$'https://mirror-one.invalid/coreutils-9.11.tar.xz\nhttps://mirror-two.invalid/coreutils-9.11.tar.xz'

# A valid existing archive must be reused without contacting any mirror.
cp -- "$tmp/fixture.tar.xz" "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null
[[ ! -e "$FAKE_WGET_LOG" ]] || fail "A valid existing archive triggered a mirror download."

# A missing archive must fall back after the first mirror fails.
rm -f -- "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null 2>&1 || fail "Mirror fallback failed for a missing archive."
cmp -s "$tmp/fixture.tar.xz" "$SOURCES/$ARCHIVE" || fail "Fallback archive contents are incorrect."
[[ "$(wc -l < "$FAKE_WGET_LOG")" -eq 2 ]] || fail "Fallback did not try both configured mirrors."

# A corrupt existing archive must be replaced only by checksum-valid bytes.
: > "$FAKE_WGET_LOG"
printf '%s\n' 'corrupt-existing-archive' > "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null 2>&1 || fail "Mirror fallback failed for a corrupt existing archive."
cmp -s "$tmp/fixture.tar.xz" "$SOURCES/$ARCHIVE" || fail "Corrupt archive was not replaced by verified bytes."

# A bad mirror response must not replace the existing file.
printf '%s\n' 'keep-existing-on-failure' > "$SOURCES/$ARCHIVE"
if COREUTILS_MIRROR_URLS="https://mirror-bad.invalid/coreutils-9.11.tar.xz" \
    bash "$HELPER" "$SOURCES" >/dev/null 2>&1; then
  fail "Fallback accepted a mirror response with the wrong checksum."
fi
grep -Fxq 'keep-existing-on-failure' "$SOURCES/$ARCHIVE" ||
  fail "A failed fallback overwrote the existing archive."

# Non-HTTPS mirrors are ignored and temporary files are always removed.
if COREUTILS_MIRROR_URLS="http://mirror-bad.invalid/coreutils-9.11.tar.xz" \
    bash "$HELPER" "$SOURCES" >/dev/null 2>&1; then
  fail "Fallback accepted a non-HTTPS mirror."
fi
if find "$SOURCES" -maxdepth 1 -type f -name ".${ARCHIVE}.*" | grep -q .; then
  fail "Fallback left an unverified temporary archive behind."
fi

echo "LFS coreutils mirror fallback regression tests: OK"
