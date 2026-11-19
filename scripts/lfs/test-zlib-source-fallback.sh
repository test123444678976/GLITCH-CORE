#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$ROOT/scripts/lfs/ensure-zlib-source.sh"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$HELPER" || fail "zlib source fallback has invalid Bash syntax."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sources" "$tmp/bin"
printf 'fixture zlib source archive\n' > "$tmp/fixture.tar.gz"
(cd "$tmp" && md5sum fixture.tar.gz) > "$tmp/sources/md5sums"

cat > "$tmp/bin/wget" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
for arg in "$@"; do
  case "$arg" in
    --output-document=*) output="${arg#*=}" ;;
  esac
done
url="${!#}"
[[ -n "$output" ]] || exit 2
if [[ -n "${WGET_MARKER:-}" ]]; then : > "$WGET_MARKER"; fi
case "$url" in
  https://fixture.invalid/good)
    cp -- "$FIXTURE_ARCHIVE" "$output"
    ;;
  https://fixture.invalid/bad)
    printf '<html>not an archive</html>\n' > "$output"
    ;;
  *)
    exit 22
    ;;
esac
EOF
chmod +x "$tmp/bin/wget"

# A valid existing archive must be reused without contacting any mirror.
cp "$tmp/fixture.tar.gz" "$tmp/sources/zlib-1.3.2.tar.gz"
PATH="$tmp/bin:$PATH" FIXTURE_ARCHIVE="$tmp/fixture.tar.gz" \
  WGET_MARKER="$tmp/wget-called" \
  ZLIB_MIRROR_URLS="https://fixture.invalid/good" \
  bash "$HELPER" "$tmp/sources" >/dev/null
[[ ! -e "$tmp/wget-called" ]] || fail "Fallback downloaded despite an already valid archive."

# An HTML/error page from the primary URL is replaced only by a checksum-valid mirror file.
printf '<html>blocked response</html>\n' > "$tmp/sources/zlib-1.3.2.tar.gz"
PATH="$tmp/bin:$PATH" FIXTURE_ARCHIVE="$tmp/fixture.tar.gz" \
  ZLIB_MIRROR_URLS="https://fixture.invalid/good" \
  bash "$HELPER" "$tmp/sources" >/dev/null
cmp -s "$tmp/fixture.tar.gz" "$tmp/sources/zlib-1.3.2.tar.gz" \
  || fail "Fallback did not install the checksum-valid zlib archive."

# A mirror response with the wrong checksum must be rejected without replacing the source.
printf '<html>blocked response</html>\n' > "$tmp/sources/zlib-1.3.2.tar.gz"
if PATH="$tmp/bin:$PATH" FIXTURE_ARCHIVE="$tmp/fixture.tar.gz" \
    ZLIB_MIRROR_URLS="https://fixture.invalid/bad" \
    bash "$HELPER" "$tmp/sources" >/dev/null 2>&1; then
  fail "Fallback accepted an invalid mirror response."
fi
grep -Fq 'blocked response' "$tmp/sources/zlib-1.3.2.tar.gz" \
  || fail "Invalid mirror response unexpectedly replaced the existing archive."
if compgen -G "$tmp/sources/.zlib-1.3.2.tar.gz.*" >/dev/null; then
  fail "Fallback left a temporary archive behind."
fi

echo "LFS zlib source mirror fallback regression tests: OK"
