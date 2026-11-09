#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE LFS 13.1-systemd host preflight.
# Read-only: this script does not install packages, change /bin/sh,
# create partitions, format disks, mount filesystems, or run builds.

failures=0
warnings=0

ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; failures=$((failures + 1)); }

echo "GLITCH//CORE — LFS 13.1-systemd host check"
echo "This check is read-only."
echo

if [[ "$(uname -m)" == "x86_64" ]]; then
    ok "Host architecture: x86_64"
else
    fail "Host architecture is $(uname -m); this project target is x86_64"
fi

if [[ "$(uname -s)" == "Linux" ]]; then
    ok "Host operating system: Linux"
else
    fail "LFS build host must be Linux (detected: $(uname -s))"
fi

required=(
    bash gcc g++ ld make bison awk gawk diff find grep gzip m4 patch
    perl python3 sed tar makeinfo xz wget md5sum file
)

echo "== Required commands =="
for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    else
        fail "Missing command: $cmd"
    fi
done

echo
echo "== Host versions =="

if command -v gcc >/dev/null 2>&1; then
    gcc_version="$(gcc -dumpfullversion -dumpversion)"
    echo "GCC: $gcc_version"
    gcc_ceiling="$(printf '%s\n' "$gcc_version" 16.2.0 | sort -V | tail -n1)"
    if [[ "$gcc_ceiling" == "16.2.0" ]]; then
        ok "GCC is at or below the LFS 13.1 tested ceiling (16.2.0)"
    else
        warn "GCC $gcc_version is newer than 16.2.0; LFS 13.1 says newer versions are untested"
    fi
fi

if command -v ld >/dev/null 2>&1; then
    binutils_version="$(ld --version | sed -n '1s/.*) //p' | awk '{print $1}')"
    echo "Binutils ld: $binutils_version"
    if [[ -n "$binutils_version" ]]; then
        if [[ "$(printf '%s\n' 2.47 "$binutils_version" | sort -V | tail -n1)" == "$binutils_version" && "$binutils_version" != "2.47" ]]; then
            warn "Binutils $binutils_version is newer than 2.47; LFS 13.1 says newer versions are untested"
        else
            ok "Binutils is at or below the LFS 13.1 tested ceiling (2.47)"
        fi
    else
        warn "Could not parse the binutils version"
    fi
fi

kernel_version="$(uname -r | sed 's/[^0-9.].*//')"
echo "Kernel: $(uname -r)"
if [[ "$(printf '%s\n' 5.10 "$kernel_version" | sort -V | head -n1)" == "5.10" ]]; then
    ok "Host kernel meets the 5.10 minimum"
else
    fail "Host kernel is older than 5.10"
fi

echo
echo "== Recommended resources =="

cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
mem_gb=$((mem_kb / 1024 / 1024))
echo "CPU cores: $cores"
echo "RAM: ${mem_gb} GiB"
if (( cores >= 4 )); then ok "At least 4 CPU cores"; else warn "LFS recommends at least 4 CPU cores"; fi
if (( mem_gb >= 8 )); then ok "At least 8 GiB RAM"; else warn "LFS recommends at least 8 GiB RAM"; fi

if [[ -e /bin/sh ]]; then
    sh_target="$(readlink -f /bin/sh 2>/dev/null || true)"
    echo "/bin/sh -> ${sh_target:-unknown}"
    if [[ "$sh_target" == */bash ]]; then
        ok "/bin/sh resolves to Bash"
    else
        warn "LFS 13.1 expects /bin/sh to resolve to Bash; do not change it blindly on the host"
    fi
fi

echo
echo "== Result =="
echo "Failures: $failures"
echo "Warnings: $warnings"
if (( failures > 0 )); then
    echo "Host check failed. Resolve the required items before starting the LFS build."
    exit 1
fi

echo "Required checks passed. Review warnings and the official LFS 13.1-systemd book before building."
