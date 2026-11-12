#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/scripts/lfs/ensure-ncurses-source.sh"
ARCHIVE="ncurses-6.6.tar.gz"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$HELPER" || fail "ncurses source fallback helper has invalid Bash syntax."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
SOURCES="$tmp/sources"
STUBS="$tmp/stubs"
mkdir -p "$SOURCES" "$STUBS"

payload='GLITCHCORE ncurses source fixture'
digest="$(printf '%s' "$payload" | md5sum | awk '{print $1}')"
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
  *mirror-two.invalid/*) printf '%s' "$FAKE_WGET_CONTENT" > "$output" ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$STUBS/wget"
export PATH="$STUBS:$PATH"
export FAKE_WGET_LOG="$tmp/wget.log"
export FAKE_WGET_CONTENT="$payload"
export NCURSES_MIRROR_URLS=$'https://mirror-one.invalid/ncurses-6.6.tar.gz\nhttps://mirror-two.invalid/ncurses-6.6.tar.gz'

# A correct archive must be reused without contacting any mirror.
printf '%s' "$payload" > "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null
test ! -e "$FAKE_WGET_LOG" || fail "A valid existing archive triggered a mirror download."

# A missing archive must fall back to the second mirror after the first fails.
rm -f "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null 2>&1 || fail "Mirror fallback failed for a missing archive."
test "$(cat "$SOURCES/$ARCHIVE")" = "$payload" || fail "Fallback archive contents are incorrect."
test "$(wc -l < "$FAKE_WGET_LOG")" -eq 2 || fail "Fallback did not try both mirrors."

# A corrupt partial archive must be replaced only by checksum-valid bytes.
: > "$FAKE_WGET_LOG"
printf '%s' 'partial-corrupt-download' > "$SOURCES/$ARCHIVE"
bash "$HELPER" "$SOURCES" >/dev/null 2>&1 || fail "Mirror fallback failed for a corrupt archive."
test "$(cat "$SOURCES/$ARCHIVE")" = "$payload" || fail "Corrupt archive was not replaced."

# A bad manifest digest must fail closed and preserve the previous file.
: > "$FAKE_WGET_LOG"
printf '%s  %s\n' '00000000000000000000000000000000' "$ARCHIVE" > "$SOURCES/md5sums"
printf '%s' 'keep-existing' > "$SOURCES/$ARCHIVE"
if bash "$HELPER" "$SOURCES" >/dev/null 2>&1; then
  fail "Fallback accepted an archive that did not match the manifest."
fi
test "$(cat "$SOURCES/$ARCHIVE")" = 'keep-existing' || fail "Failed fallback overwrote the existing archive."
if find "$SOURCES" -maxdepth 1 -type f -name ".${ARCHIVE}.*" | grep -q .; then
  fail "Fallback left an unverified temporary archive behind."
fi

echo "LFS ncurses mirror fallback regression tests: OK"
