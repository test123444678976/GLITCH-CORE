#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE — LFS r13.1-systemd Chapter 5 cross-toolchain.
# Completes Binutils Pass 1, GCC Pass 1, Linux API headers, Glibc and target Libstdc++.
# Run as the unprivileged LFS build user on an x86_64 Linux host.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LFS="${LFS:-$ROOT/work-lfs/lfs}"
SOURCES="$LFS/sources"
TOOLS="$LFS/tools"
LFS_TGT="${LFS_TGT:-x86_64-lfs-linux-gnu}"
JOBS="${JOBS:-2}"

BINUTILS_VERSION="2.47"
GCC_VERSION="16.2.0"
LINUX_VERSION="7.3.1"
GLIBC_VERSION="2.44"

fail() { echo "ERROR: $*" >&2; exit 1; }
log()  { echo; echo "==> $*"; }

[[ "$(uname -s)" == "Linux" ]] || fail "LFS builds require a Linux host."
[[ "$(uname -m)" == "x86_64" ]] || fail "This build currently targets x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Never run an LFS build as root."
[[ "$LFS_TGT" == "x86_64-lfs-linux-gnu" ]] || fail "Unexpected target triplet: $LFS_TGT"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."
[[ -d "$LFS" && -d "$SOURCES" && -d "$TOOLS" ]] || fail "LFS, sources and tools directories must already exist."
[[ -w "$LFS" && -w "$TOOLS" ]] || fail "The LFS build user must own the dedicated LFS workspace."

for cmd in tar xz make gcc g++ ld awk sed find patch cp readelf; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing host command: $cmd"
done

export LFS LFS_TGT
export PATH="$TOOLS/bin:$PATH"
export LC_ALL=POSIX
umask 022

verify_source() {
  local name="$1"
  [[ "$name" == "$(basename "$name")" && "$name" != "." && "$name" != ".." ]] || fail "Unsafe source filename: $name"
  bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$SOURCES" "$name" >/dev/null
}

source_archive() {
  local name="$1"
  verify_source "$name"
  printf '%s\n' "$SOURCES/$name"
}

extract_source() {
  local archive="$1"
  local directory="$2"
  [[ "$directory" == "$SOURCES/"* && "$directory" != "$SOURCES" ]] || fail "Refusing extraction outside sources: $directory"
  [[ ! -L "$directory" ]] || fail "Refusing symlinked source directory: $directory"
  rm -rf -- "$directory"
  tar -xf "$archive" -C "$SOURCES"
  [[ -d "$directory" && ! -L "$directory" ]] || fail "Expected source directory missing: $directory"
}

prepare_lfs_layout() {
  mkdir -p "$LFS/etc" "$LFS/var" "$LFS/usr/bin" "$LFS/usr/lib" "$LFS/usr/sbin" "$LFS/lib64"
  for path in bin lib sbin; do
    if [[ -e "$LFS/$path" || -L "$LFS/$path" ]]; then
      [[ -L "$LFS/$path" && "$(readlink "$LFS/$path")" == "usr/$path" ]] || fail "Unexpected existing LFS path: $LFS/$path"
    else
      ln -s "usr/$path" "$LFS/$path"
    fi
  done
}

build_linux_headers() {
  local src="$SOURCES/linux-$LINUX_VERSION"
  log "Installing sanitized Linux $LINUX_VERSION API headers"
  extract_source "$(source_archive "linux-$LINUX_VERSION.tar.xz")" "$src"
  cd "$src"
  make mrproper
  make headers
  find usr/include -type f ! -name '*.h' -delete
  mkdir -p "$LFS/usr"
  cp -a usr/include "$LFS/usr/"
  test -s "$LFS/usr/include/linux/version.h" || fail "Linux API headers were not installed."
  touch "$TOOLS/.glitchcore-linux-headers-complete"
}

build_glibc() {
  local src="$SOURCES/glibc-$GLIBC_VERSION"
  log "Building cross Glibc $GLIBC_VERSION"
  extract_source "$(source_archive "glibc-$GLIBC_VERSION.tar.xz")" "$src"
  verify_source "glibc-fhs-1.patch"
  verify_source "glibc-$GLIBC_VERSION-upstream_fixes-4.patch"
  cd "$src"
  patch -Np1 -i "$SOURCES/glibc-fhs-1.patch"
  patch -Np1 -i "$SOURCES/glibc-$GLIBC_VERSION-upstream_fixes-4.patch"

  case "$(uname -m)" in
    x86_64)
      ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
      ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
      ;;
  esac

  mkdir -p build
  cd build
  echo "rootsbindir=/usr/sbin" > configparms
  ../configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(../scripts/config.guess)" \
    --disable-nscd \
    libc_cv_slibdir=/usr/lib \
    --enable-kernel=5.10
  # LFS notes intermittent parallel-build failures in Glibc; use a serial build.
  make
  sed '/RTLDLIST=/s@/usr@@g' -i elf/ldd
  make DESTDIR="$LFS" install

  log "Checking the new cross compiler and target C runtime"
  printf 'int main(void) { return 0; }\n' | "$LFS_TGT-gcc" -x c - -v -Wl,--verbose > dummy.log 2>&1
  "$LFS_TGT-readelf" -l a.out | grep -Fq '/lib64/ld-linux-x86-64.so.2' || fail "Cross compiler did not select the LFS dynamic loader."
  grep -Fq "$LFS/usr/include" dummy.log || fail "Cross compiler is not using the LFS headers."
  grep -Fq "$LFS/usr/lib/libc.so.6" dummy.log || fail "Cross compiler is not linking against the LFS Glibc."
  rm -f a.out dummy.log
  touch "$TOOLS/.glitchcore-glibc-complete"
}

build_libstdcxx() {
  local src="$SOURCES/gcc-$GCC_VERSION"
  log "Building target Libstdc++ from GCC $GCC_VERSION"
  [[ -d "$src/libstdc++-v3" && ! -L "$src" ]] || extract_source "$(source_archive "gcc-$GCC_VERSION.tar.xz")" "$src"
  mkdir -p "$src/build-libstdcxx"
  cd "$src/build-libstdcxx"
  ../libstdc++-v3/configure \
    --host="$LFS_TGT" \
    --build="$(../config.guess)" \
    CXX="$LFS_TGT-gcc" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/tools/$LFS_TGT/include/c++/$GCC_VERSION"
  make -j"$JOBS"
  make DESTDIR="$LFS" install
  rm -f "$LFS/usr/lib/libstdc++.la" "$LFS/usr/lib/libstdc++exp.la" "$LFS/usr/lib/libstdc++fs.la" "$LFS/usr/lib/libsupc++.la"
  test -s "$LFS/usr/lib/libstdc++.so.6" || fail "Target Libstdc++ shared library is missing."
  touch "$TOOLS/.glitchcore-libstdcxx-complete"
}

log "GLITCH//CORE — complete LFS Chapter 5 cross-toolchain"
echo "LFS=$LFS"
echo "LFS_TGT=$LFS_TGT"
echo "Sources=$SOURCES"
echo "Jobs=$JOBS"

prepare_lfs_layout
bash "$ROOT/scripts/lfs/build-toolchain-pass1.sh" all
build_linux_headers
build_glibc
build_libstdcxx

log "Chapter 5 cross-toolchain build finished"
echo "Checkpoints: Binutils Pass 1, GCC Pass 1, Linux API headers, Glibc, Libstdc++."
echo "This is the cross-toolchain stage only; Chapters 6 and 7 temporary tools remain."
