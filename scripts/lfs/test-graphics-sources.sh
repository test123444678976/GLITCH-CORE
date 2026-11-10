#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/lfs/validate-graphics-sources.sh"
FETCHER="$ROOT/scripts/lfs/fetch-graphics-sources.sh"
LOCK="$ROOT/config/graphics-sources.lock"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$VALIDATOR"
bash -n "$FETCHER"
bash "$VALIDATOR" "$LOCK"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
valid='mesa|26.2.6|mesa-26.2.6.tar.xz|https://archive.mesa3d.org/mesa-26.2.6.tar.xz|b9436b3e1a8be76fbd4823dc884f90596ab7c6ac5e1867a305e66ffccfb31a92'
printf '%s\n' "$valid" > "$tmp/valid.lock"
bash "$VALIDATOR" "$tmp/valid.lock" >/dev/null

reject() {
  local label="$1" line="$2"
  printf '%s\n' "$line" > "$tmp/invalid.lock"
  if bash "$VALIDATOR" "$tmp/invalid.lock" >/dev/null 2>&1; then
    fail "Validator accepted invalid lock entry: $label"
  fi
}
reject "non-HTTPS URL" 'mesa|26.2.6|mesa-26.2.6.tar.xz|http://archive.mesa3d.org/mesa-26.2.6.tar.xz|b9436b3e1a8be76fbd4823dc884f90596ab7c6ac5e1867a305e66ffccfb31a92'
reject "unapproved host" 'mesa|26.2.6|mesa-26.2.6.tar.xz|https://example.invalid/mesa-26.2.6.tar.xz|b9436b3e1a8be76fbd4823dc884f90596ab7c6ac5e1867a305e66ffccfb31a92'
reject "invalid checksum" 'mesa|26.2.6|mesa-26.2.6.tar.xz|https://archive.mesa3d.org/mesa-26.2.6.tar.xz|not-a-sha256'
reject "URL/archive mismatch" 'mesa|26.2.6|mesa-26.2.6.tar.xz|https://archive.mesa3d.org/other.tar.xz|b9436b3e1a8be76fbd4823dc884f90596ab7c6ac5e1867a305e66ffccfb31a92'

cat "$tmp/valid.lock" "$tmp/valid.lock" > "$tmp/duplicate.lock"
if bash "$VALIDATOR" "$tmp/duplicate.lock" >/dev/null 2>&1; then
  fail "Validator accepted duplicate package/archive entries."
fi

grep -q 'sha256sum --check' "$FETCHER" || fail "Downloader does not verify SHA-256."
grep -q -- "--proto '=https'" "$FETCHER" || fail "Downloader does not restrict curl to HTTPS."
grep -q -- "--proto-redir '=https'" "$FETCHER" || fail "Downloader does not restrict redirects to HTTPS."
grep -q '! -L "$final"' "$FETCHER" || fail "Downloader does not reject symlinked archive destinations."
grep -q 'validate-graphics-sources.sh' "$FETCHER" || fail "Downloader does not validate its lockfile first."
grep -q 'PACKAGE_FILTER="${3:-}"' "$FETCHER" || fail "Downloader does not support per-package source selection."
grep -q 'No package matched the requested source filter' "$FETCHER" || fail "Downloader does not fail when a source filter matches nothing."

# Exercise the symlink-destination guard without network access.
mkdir -p "$tmp/bin" "$tmp/dest"
cat > "$tmp/bin/curl" <<'CURL'
#!/usr/bin/env bash
echo called > "$CURL_MARKER"
exit 99
CURL
chmod +x "$tmp/bin/curl"
ln -s /dev/null "$tmp/dest/mesa-26.2.6.tar.xz"
export CURL_MARKER="$tmp/curl-was-called"
if PATH="$tmp/bin:$PATH" bash "$FETCHER" "$tmp/valid.lock" "$tmp/dest" >/dev/null 2>&1; then
  fail "Downloader accepted a symlinked archive destination."
fi
[[ ! -e "$CURL_MARKER" ]] || fail "Downloader invoked curl before rejecting the symlink."

# Exercise package filtering with a deterministic fake curl; no network is used.
mkdir -p "$tmp/fake-bin" "$tmp/filter-dest"
printf 'fixture archive bytes\n' > "$tmp/archive.fixture"
fixture_sha="$(sha256sum "$tmp/archive.fixture" | awk '{print $1}')"
printf 'xorgproto|2026.1|xorgproto-2026.1.tar.xz|https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2026.1.tar.xz|%s\n' "$fixture_sha" > "$tmp/filter.lock"
cat > "$tmp/fake-bin/curl" <<'CURL'
#!/usr/bin/env bash
out=''
while (($#)); do
  if [[ "$1" == --output ]]; then out="$2"; shift 2; else shift; fi
done
[[ -n "$out" ]] || exit 91
cp "$CURL_FIXTURE" "$out"
CURL
chmod +x "$tmp/fake-bin/curl"
export CURL_FIXTURE="$tmp/archive.fixture"
PATH="$tmp/fake-bin:$PATH" bash "$FETCHER" "$tmp/filter.lock" "$tmp/filter-dest" xorgproto >/dev/null
cmp "$tmp/archive.fixture" "$tmp/filter-dest/xorgproto-2026.1.tar.xz" || fail "Filtered source fetch did not store the selected archive."
if PATH="$tmp/fake-bin:$PATH" bash "$FETCHER" "$tmp/filter.lock" "$tmp/filter-dest" libdrm >/dev/null 2>&1; then
  fail "Downloader accepted a package filter that matched no source."
fi

echo "Graphics source lock tests: OK"
echo "NOTE: tests use a fake downloader for filtering; they do not compile packages."
