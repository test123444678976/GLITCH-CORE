#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE — LFS 13.1-systemd Chapter 5 cross-toolchain, Pass 1.
# Implements the official Binutils 2.47 and GCC 16.2.0 Pass 1 sequence.
# Run as the unprivileged LFS build user, never as root.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LFS="${LFS:-$ROOT/work-lfs/lfs}"
SOURCES="$LFS/sources"
TOOLS="$LFS/tools"
LFS_TGT="${LFS_TGT:-$(uname -m)-lfs-linux-gnu}"
JOBS="${JOBS:-$(nproc)}"
STAGE="${1:-all}"

BINUTILS_VERSION="2.47"
GCC_VERSION="16.2.0"
GMP_VERSION="6.3.0"
MPFR_VERSION="4.2.2"
MPC_VERSION="1.4.1"

fail() { echo "ERROR: $*" >&2; exit 1; }
log()  { echo; echo "==> $*"; }

[[ "$(uname -s)" == "Linux" ]] || fail "LFS cross-toolchain builds must run on Linux."
[[ "$(uname -m)" == "x86_64" ]] || fail "This GLITCH//CORE build script currently targets x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Do not run this script as root. Use the unprivileged LFS build user."
[[ "$STAGE" == "all" || "$STAGE" == "binutils" || "$STAGE" == "gcc" ]] || fail "Usage: $0 [binutils|gcc|all]"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."
[[ -d "$LFS" ]] || fail "LFS target directory does not exist: $LFS"
[[ -d "$SOURCES" ]] || fail "LFS sources directory does not exist: $SOURCES"
[[ -d "$TOOLS" ]] || fail "LFS tools directory does not exist. Prepare it as root and grant the LFS user write access."
[[ -w "$TOOLS" ]] || fail "LFS user cannot write to $TOOLS. Fix ownership of this dedicated build directory."
[[ "$LFS_TGT" == "x86_64-lfs-linux-gnu" ]] || fail "Unexpected LFS_TGT: $LFS_TGT"

for cmd in tar xz make gcc g++ ld awk sed; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing host command: $cmd"
done

archive() {
    local pattern="$1"
    local found
    found="$(find "$SOURCES" -maxdepth 1 -type f -name "$pattern" -print -quit)"
    [[ -n "$found" ]] || fail "Required source archive missing ($pattern). Run scripts/build-lfs.sh first."
    printf '%s\n' "$found"
}

extract_once() {
    local archive_path="$1"
    local expected_dir="$2"
    if [[ ! -d "$expected_dir" ]]; then
        log "Extracting $(basename "$archive_path")"
        tar -xf "$archive_path" -C "$SOURCES"
    fi
    [[ -d "$expected_dir" ]] || fail "Expected source directory was not created: $expected_dir"
}

build_binutils() {
    local src="$SOURCES/binutils-$BINUTILS_VERSION"
    local build="$src/build"

    if [[ -f "$TOOLS/.glitchcore-binutils-pass1-complete" ]]; then
        log "Binutils Pass 1 already marked complete; skipping."
        return
    fi

    extract_once "$(archive "binutils-$BINUTILS_VERSION.tar.*")" "$src"
    mkdir -p "$build"

    log "Configuring Binutils $BINUTILS_VERSION for $LFS_TGT"
    cd "$build"
    ../configure \
        --prefix="$TOOLS" \
        --with-sysroot="$LFS" \
        --target="$LFS_TGT" \
        --disable-nls \
        --enable-gprofng=no \
        --disable-werror \
        --enable-new-dtags \
        --enable-default-hash-style=gnu

    log "Building Binutils (JOBS=$JOBS)"
    make -j"$JOBS"

    log "Installing Binutils into the isolated LFS tools directory"
    make install

    "$TOOLS/bin/$LFS_TGT-ld" --version >/dev/null
    touch "$TOOLS/.glitchcore-binutils-pass1-complete"
    log "Binutils Pass 1 completed."
}

build_gcc() {
    local src="$SOURCES/gcc-$GCC_VERSION"
    local build="$src/build"

    [[ -f "$TOOLS/.glitchcore-binutils-pass1-complete" ]] || fail "Build Binutils Pass 1 before GCC Pass 1."
    if [[ -f "$TOOLS/.glitchcore-gcc-pass1-complete" ]]; then
        log "GCC Pass 1 already marked complete; skipping."
        return
    fi

    extract_once "$(archive "gcc-$GCC_VERSION.tar.*")" "$src"

    # GCC's build system detects these in-tree dependency directories.
    extract_once "$(archive "mpfr-$MPFR_VERSION.tar.*")" "$src/mpfr-$MPFR_VERSION"
    extract_once "$(archive "gmp-$GMP_VERSION.tar.*")" "$src/gmp-$GMP_VERSION"
    extract_once "$(archive "mpc-$MPC_VERSION.tar.*")" "$src/mpc-$MPC_VERSION"

    [[ ! -e "$src/mpfr" ]] && mv "$src/mpfr-$MPFR_VERSION" "$src/mpfr"
    [[ ! -e "$src/gmp"  ]] && mv "$src/gmp-$GMP_VERSION" "$src/gmp"
    [[ ! -e "$src/mpc"  ]] && mv "$src/mpc-$MPC_VERSION" "$src/mpc"

    mkdir -p "$build"
    log "Configuring GCC $GCC_VERSION Pass 1 for $LFS_TGT"
    cd "$build"
    ../configure \
        --target="$LFS_TGT" \
        --prefix="$TOOLS" \
        --with-glibc-version=2.44 \
        --with-sysroot="$LFS" \
        --with-newlib \
        --without-headers \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-fixincludes \
        --enable-initfini-array \
        --disable-nls \
        --disable-shared \
        --disable-multilib \
        --disable-threads \
        --disable-libatomic \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libvtv \
        --disable-libstdcxx \
        --enable-languages=c,c++

    log "Building GCC (JOBS=$JOBS)"
    make -j"$JOBS"

    log "Installing GCC Pass 1 into the isolated LFS tools directory"
    make install

    local compiler="$TOOLS/bin/$LFS_TGT-gcc"
    [[ -x "$compiler" ]] || fail "Cross GCC was not installed at $compiler"
    local include_dir
    include_dir="$("$compiler" -print-file-name=include)"
    [[ -d "$include_dir" ]] || fail "Could not locate GCC internal include directory: $include_dir"

    log "Completing GCC's internal limits.h"
    cat ../gcc/limitx.h ../gcc/glimits.h ../gcc/limity.h > "$include_dir/limits.h"

    "$compiler" -dumpmachine | grep -Fx "$LFS_TGT" >/dev/null
    touch "$TOOLS/.glitchcore-gcc-pass1-complete"
    log "GCC Pass 1 completed."
}

log "GLITCH//CORE LFS Chapter 5 — cross-toolchain Pass 1"
echo "Target:  $LFS_TGT"
echo "LFS:     $LFS"
echo "Sources: $SOURCES"
echo "Tools:   $TOOLS"
echo "Jobs:    $JOBS"
echo "Stage:   $STAGE"
echo "User:    $(id -un)"

if [[ "$STAGE" == "binutils" || "$STAGE" == "all" ]]; then
    build_binutils
fi
if [[ "$STAGE" == "gcc" || "$STAGE" == "all" ]]; then
    build_gcc
fi

log "Requested toolchain stage(s) finished."
echo "This completes only Chapter 5 Binutils/GCC Pass 1; it is not a bootable LFS system."
