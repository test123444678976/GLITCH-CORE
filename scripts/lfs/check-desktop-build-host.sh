#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only host preflight for compiling the GLITCH//CORE graphical desktop.
# This checks tools and resources only; it does not install packages or build
# the LFS target. Run on a Linux x86_64 build host, not Windows/WSL1.

failures=0
warnings=0
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[FAIL] %s\n' "$*" >&2; failures=$((failures + 1)); }

echo "GLITCH//CORE — graphical desktop build-host preflight (read-only)"
echo

[[ "$(uname -s)" == Linux ]] && ok "Linux build host" || fail "A native Linux build host is required."
[[ "$(uname -m)" == x86_64 ]] && ok "x86_64 architecture" || fail "Expected x86_64, got $(uname -m)."

required=(
  bash gcc g++ ld make ar ranlib strip
  meson ninja cmake pkg-config python3 perl
  autoconf automake libtoolize m4 bison flex
  gettext msgfmt gawk awk sed grep find xargs
  tar xz gzip bzip2 patch diff file
  makeinfo
)
echo "== Required build tools =="
for cmd in "${required[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd"
  else
    fail "Missing command: $cmd"
  fi
done

optional=(
  curl wget git rsync ccache
  xsltproc xmlto docbook2x
  gperf autopoint intltoolize
  xorriso mtools grub-mkrescue
)
echo
echo "== Recommended tools (warnings only) =="
for cmd in "${optional[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd"; else warn "Optional tool missing: $cmd"; fi
done

echo
echo "== Available resources =="
cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
mem_gib=$((mem_kb / 1024 / 1024))
free_kib="$(df -Pk "${TMPDIR:-/tmp}" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)"
free_gib=$((free_kib / 1024 / 1024))
echo "CPU cores: $cores"
echo "RAM:       ${mem_gib} GiB"
echo "Free /tmp: ${free_gib} GiB"
(( cores >= 4 )) && ok "At least 4 CPU cores" || warn "4+ cores recommended; builds will be slower."
(( mem_gib >= 8 )) && ok "At least 8 GiB RAM" || warn "8+ GiB RAM recommended; large C++ builds may need swap."
(( free_gib >= 80 )) && ok "At least 80 GiB free in temporary filesystem" || warn "80+ GiB free space recommended for source/build trees."

echo
echo "== Result =="
echo "Failures: $failures"
echo "Warnings: $warnings"
if (( failures > 0 )); then
  echo "Desktop build-host preflight FAILED. Install missing tools before building."
  exit 1
fi
echo "Desktop build-host preflight PASSED."
echo "This is only a host check: it does not validate LFS sources, compile packages, or prove the target desktop works."
