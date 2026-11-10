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
# Exercise the relocatable staging manifest with x86_64 ELF fixtures.
command -v file >/dev/null 2>&1 || fail "file is required for staging audit tests."
stage="$tmp/stage"
for package in dpkg apt; do
  mkdir -p "$stage/$package/usr/bin" "$stage/$package/usr/share/glitch-core"
done
for bin in dpkg dpkg-deb dpkg-query; do cp /bin/true "$stage/dpkg/usr/bin/$bin"; chmod 0755 "$stage/dpkg/usr/bin/$bin"; done
for bin in apt-get apt-cache; do cp /bin/true "$stage/apt/usr/bin/$bin"; chmod 0755 "$stage/apt/usr/bin/$bin"; done
printf 'package=dpkg\nversion=1.23.11\nsource_sha256=%064d\ninstall_mode=DESTDIR\n' 0 > "$stage/dpkg/usr/share/glitch-core/dpkg-build-info"
printf 'package=apt\nversion=3.0.4\nsource_sha256=%064d\ninstall_mode=DESTDIR\n' 0 > "$stage/apt/usr/share/glitch-core/apt-build-info"
(cd "$stage/dpkg" && find . -type f -print | LC_ALL=C sort > installed-files.txt)
(cd "$stage/apt" && find . -type f -print | LC_ALL=C sort > installed-files.txt)
bash "$ROOT/scripts/lfs/test-package-manager-stage.sh" "$stage"
mv "$stage" "$tmp/relocated-stage"
bash "$ROOT/scripts/lfs/test-package-manager-stage.sh" "$tmp/relocated-stage"
printf '%s\n' "$tmp/relocated-stage/dpkg/usr/bin/dpkg" > "$tmp/relocated-stage/dpkg/installed-files.txt"
if bash "$ROOT/scripts/lfs/test-package-manager-stage.sh" "$tmp/relocated-stage" >/dev/null 2>&1; then
  fail "Staging audit accepted an absolute, non-relocatable manifest entry."
fi
printf './../../etc/passwd\n' > "$tmp/relocated-stage/dpkg/installed-files.txt"
if bash "$ROOT/scripts/lfs/test-package-manager-stage.sh" "$tmp/relocated-stage" >/dev/null 2>&1; then
  fail "Staging audit accepted a manifest path traversal."
fi
echo "Relocatable native package staging manifest tests: OK"

echo "Native dpkg/APT source and build-pipeline tests: OK"
