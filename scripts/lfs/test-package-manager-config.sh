#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/lfs/install-package-manager-config.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail(){ echo "ERROR: $*" >&2; exit 1; }

bash -n "$SCRIPT"
mkdir -p "$TMP/target/etc" "$TMP/target/usr/bin"
for bin in dpkg dpkg-deb apt-get apt-cache; do
  printf '#!/bin/sh\nexit 0\n' > "$TMP/target/usr/bin/$bin"
  chmod +x "$TMP/target/usr/bin/$bin"
done

bash "$SCRIPT" "$TMP/target"
[[ -s "$TMP/target/etc/apt/apt.conf" ]] || fail "APT configuration was not installed."
[[ -s "$TMP/target/etc/apt/sources.list" ]] || fail "APT sources list was not installed."
[[ -f "$TMP/target/var/lib/dpkg/status" ]] || fail "dpkg status database was not initialized."
[[ -d "$TMP/target/var/lib/apt/lists/partial" ]] || fail "APT partial-list directory is missing."
grep -Fq 'Acquire::AllowInsecureRepositories "false";' "$TMP/target/etc/apt/apt.conf" ||
  fail "APT must reject insecure repositories by default."
if grep -Eq '^[[:space:]]*deb(-src)?[[:space:]]' "$TMP/target/etc/apt/sources.list"; then
  fail "An external repository must not be enabled by default."
fi

# Existing target path components must not redirect writes outside the rootfs.
for component in etc var; do
  linked="$TMP/symlink-$component"
  outside="$TMP/outside-$component"
  mkdir -p "$linked/etc" "$linked/usr/bin" "$outside"
  for bin in dpkg dpkg-deb apt-get apt-cache; do
    printf '#!/bin/sh\nexit 0\n' > "$linked/usr/bin/$bin"
    chmod +x "$linked/usr/bin/$bin"
  done
  rm -rf "$linked/$component"
  ln -s "$outside" "$linked/$component"
  if bash "$SCRIPT" "$linked" >/dev/null 2>&1; then
    fail "Accepted a symlinked target $component directory."
  fi
  [[ -z "$(find "$outside" -mindepth 1 -print -quit)" ]] ||
    fail "Wrote package-manager configuration outside the target through $component symlink."
done

# A target without native dpkg/APT executables must be rejected before writes.
mkdir -p "$TMP/incomplete/etc" "$TMP/incomplete/usr/bin"
if bash "$SCRIPT" "$TMP/incomplete" >/dev/null 2>&1; then
  fail "Accepted a target without native package-manager executables."
fi
[[ ! -e "$TMP/incomplete/etc/apt" ]] || fail "Wrote APT configuration into an incomplete target."

# Resolve symlinks before the host-root safety check.
ln -s / "$TMP/root-link"
if bash "$SCRIPT" "$TMP/root-link" >/dev/null 2>&1; then
  fail "Accepted a symlink resolving to the host root."
fi

echo "APT/dpkg target configuration tests: OK"
echo "Verified native-binary gate, safe defaults, empty repository list and host-root protection."
