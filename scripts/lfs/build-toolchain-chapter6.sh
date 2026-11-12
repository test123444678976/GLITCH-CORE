#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE — LFS 13.1-systemd Chapter 6 temporary cross tools.
# Recipes and package order follow the released stable-systemd LFS 13.1 book.
# Run as the unprivileged LFS build account, never as root.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LFS="${LFS:-$ROOT/work-lfs/lfs}"
SOURCES="$LFS/sources"
TOOLS="$LFS/tools"
LFS_TGT="${LFS_TGT:-x86_64-lfs-linux-gnu}"
JOBS="${JOBS:-2}"

fail() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

[[ "$(uname -s)" == Linux ]] || fail "LFS builds require a Linux host."
[[ "$(uname -m)" == x86_64 ]] || fail "This build currently targets x86_64."
[[ "$(id -u)" -ne 0 ]] || fail "Never run an LFS build as root."
[[ "$LFS_TGT" == x86_64-lfs-linux-gnu ]] || fail "Unexpected target: $LFS_TGT"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."
[[ -d "$LFS/sources" && -d "$LFS/tools" ]] || fail "Chapter 5 checkpoint is missing."
[[ -w "$LFS" && -w "$TOOLS" ]] || fail "LFS workspace is not writable by this build user."

for cmd in tar make gcc g++ awk sed find patch readelf; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing host command: $cmd"
done
for marker in \
  .glitchcore-binutils-pass1-complete \
  .glitchcore-gcc-pass1-complete \
  .glitchcore-linux-headers-complete \
  .glitchcore-glibc-complete \
  .glitchcore-libstdcxx-complete; do
  [[ -f "$TOOLS/$marker" ]] || fail "Chapter 5 marker missing: $marker"
done

export LFS LFS_TGT
export PATH="$TOOLS/bin:$PATH"
export LC_ALL=POSIX
umask 022

archive() {
  local name="$1"
  [[ "$name" == "$(basename "$name")" ]] || fail "Unsafe archive name: $name"
  bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$SOURCES" "$name" >/dev/null
  printf '%s\n' "$SOURCES/$name"
}

extract_clean() {
  local name="$1" directory="$2"
  [[ "$directory" == "$SOURCES/"* && "$directory" != "$SOURCES" ]] || fail "Unsafe extraction path: $directory"
  [[ ! -L "$directory" ]] || fail "Refusing symlinked source directory: $directory"
  rm -rf -- "$directory"
  tar -xf "$(archive "$name")" -C "$SOURCES"
  [[ -d "$directory" && ! -L "$directory" ]] || fail "Expected source directory missing: $directory"
}

build_autoconf() {
  local package="$1" version="$2" name="$3" configure_args="$4"
  local src="$SOURCES/$package-$version"
  local marker="$TOOLS/.glitchcore-ch6-$package-complete"
  [[ -f "$marker" ]] && { log "$package already completed; skipping."; return; }
  extract_clean "$name" "$src"
  cd "$src"
  # configure_args is a trusted, script-authored argument string for the
  # pinned upstream LFS recipe; no user input is evaluated here.
  eval "./configure $configure_args"
  make -j"$JOBS"
  make DESTDIR="$LFS" install
  touch "$marker"
}

log "Writing the glibc-2.44 gnulib feature cache required by LFS 13.1"
mkdir -p "$LFS/usr/share"
cat > "$LFS/usr/share/config.site" <<'EOF'
ac_cv_func_posix_spawn_file_actions_addchdir=yes
ac_cv_func_posix_spawn_file_actions_addfchdir=yes
EOF

# 6.2 M4
build_autoconf m4 1.4.21 m4-1.4.21.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"'

# 6.3 Ncurses: build the host tic utility first, then the target shared libraries.
if [[ ! -f "$TOOLS/.glitchcore-ch6-ncurses-complete" ]]; then
  src="$SOURCES/ncurses-6.6"
  extract_clean ncurses-6.6.tar.gz "$src"
  cd "$src"
  mkdir -p build
  pushd build >/dev/null
    ../configure --prefix="$TOOLS" AWK=gawk
    make -C include
    make -C progs tic
    install -m755 progs/tic "$TOOLS/bin"
  popd >/dev/null
  ./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)" \
    --mandir=/usr/share/man --with-manpage-format=normal --with-shared \
    --without-normal --with-cxx-shared --without-debug --without-ada \
    --disable-stripping AWK=gawk
  make -j"$JOBS"
  make DESTDIR="$LFS" install
  ln -sfv libncursesw.so "$LFS/usr/lib/libncurses.so"
  sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$LFS/usr/include/curses.h"
  touch "$TOOLS/.glitchcore-ch6-ncurses-complete"
fi

# 6.4 Bash
build_autoconf bash 5.3 bash-5.3.tar.gz \
  '--prefix=/usr --build="$(sh support/config.guess)" --host="$LFS_TGT" --without-bash-malloc --docdir=/usr/share/doc/bash-5.3'
ln -sfv bash "$LFS/bin/sh"

# 6.5 Coreutils
build_autoconf coreutils 9.11 coreutils-9.11.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)" --enable-install-program=hostname'
if [[ -x "$LFS/usr/bin/chroot" ]]; then
  mkdir -p "$LFS/usr/share/man/man8"
  mv -f "$LFS/usr/bin/chroot" "$LFS/usr/sbin/chroot"
  if [[ -f "$LFS/usr/share/man/man1/chroot.1" ]]; then
    mv -f "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8"
    sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8"
  fi
fi

# 6.6 Diffutils
build_autoconf diffutils 3.12 diffutils-3.12.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" gl_cv_func_strcasecmp_works=yes --build="$(./build-aux/config.guess)"'

# 6.7 File: build a host-side file utility for the cross build.
if [[ ! -f "$TOOLS/.glitchcore-ch6-file-complete" ]]; then
  src="$SOURCES/file-5.48"
  extract_clean file-5.48.tar.gz "$src"
  cd "$src"
  mkdir -p build
  pushd build >/dev/null
    ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
    make -j"$JOBS"
  popd >/dev/null
  ./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)"
  make -j"$JOBS" FILE_COMPILE="$(pwd)/build/src/file"
  make DESTDIR="$LFS" install
  rm -f "$LFS/usr/lib/libmagic.la"
  touch "$TOOLS/.glitchcore-ch6-file-complete"
fi

# 6.8–6.16 remaining temporary utilities.
build_autoconf findutils 4.11.0 findutils-4.11.0.tar.xz \
  '--prefix=/usr --localstatedir=/var/lib/locate --host="$LFS_TGT" --build="$(build-aux/config.guess)"'

if [[ ! -f "$TOOLS/.glitchcore-ch6-gawk-complete" ]]; then
  src="$SOURCES/gawk-5.4.1"; extract_clean gawk-5.4.1.tar.xz "$src"; cd "$src"
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
  make -j"$JOBS"; make DESTDIR="$LFS" install
  touch "$TOOLS/.glitchcore-ch6-gawk-complete"
fi

build_autoconf grep 3.12 grep-3.12.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"'
build_autoconf gzip 1.14 gzip-1.14.tar.xz \
  '--prefix=/usr --host="$LFS_TGT"'
build_autoconf make 4.4.1 make-4.4.1.tar.gz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"'
build_autoconf patch 2.8 patch-2.8.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"'
build_autoconf sed 4.10 sed-4.10.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"'
build_autoconf tar 1.35 tar-1.35.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"'
build_autoconf xz 5.8.3 xz-5.8.3.tar.xz \
  '--prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)" --disable-static --docdir=/usr/share/doc/xz-5.8.3'
rm -f "$LFS/usr/lib/liblzma.la"

# 6.17 Binutils Pass 2
if [[ ! -f "$TOOLS/.glitchcore-binutils-pass2-complete" ]]; then
  src="$SOURCES/binutils-2.47"
  extract_clean binutils-2.47.tar.xz "$src"
  cd "$src"
  sed '6031s/$add_dir//' -i ltmain.sh
  mkdir -p build && cd build
  ../configure --prefix=/usr --build="$(../config.guess)" --host="$LFS_TGT" \
    --disable-nls --enable-shared --enable-gprofng=no --disable-werror \
    --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
  make -j"$JOBS"
  make DESTDIR="$LFS" install
  rm -f "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
  touch "$TOOLS/.glitchcore-binutils-pass2-complete"
fi

# 6.18 GCC Pass 2
if [[ ! -f "$TOOLS/.glitchcore-gcc-pass2-complete" ]]; then
  src="$SOURCES/gcc-16.2.0"
  extract_clean gcc-16.2.0.tar.xz "$src"
  cd "$src"
  for dep in mpfr-4.2.2 gmp-6.3.0 mpc-1.4.1; do
    [[ -d "$SOURCES/$dep" && ! -L "$SOURCES/$dep" ]] && rm -rf "$SOURCES/$dep"
  done
  tar -xf "$(archive mpfr-4.2.2.tar.xz)" -C "$SOURCES"; mv "$SOURCES/mpfr-4.2.2" mpfr
  tar -xf "$(archive gmp-6.3.0.tar.xz)" -C "$SOURCES"; mv "$SOURCES/gmp-6.3.0" gmp
  tar -xf "$(archive mpc-1.4.1.tar.xz)" -C "$SOURCES"; mv "$SOURCES/mpc-1.4.1" mpc
  sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  mkdir -p build && cd build
  unset CFLAGS CXXFLAGS LDFLAGS
  ../configure --build="$(../config.guess)" --host="$LFS_TGT" --target="$LFS_TGT" \
    --prefix=/usr --with-build-sysroot="$LFS" --enable-default-pie \
    --enable-default-ssp --disable-fixincludes --disable-nls --disable-multilib \
    --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer \
    --disable-libssp --disable-libvtv --enable-languages=c,c++ \
    CXX_FOR_TARGET="$LFS_TGT-gcc -nostdinc++" \
    LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc" \
    target_configargs=gcc_cv_target_thread_file=posix
  make -j"$JOBS"
  make DESTDIR="$LFS" install
  ln -sfv gcc "$LFS/usr/bin/cc"
  touch "$TOOLS/.glitchcore-gcc-pass2-complete"
fi

# Verify key outputs before recording the milestone.
"$LFS/usr/bin/bash" --version >/dev/null
"$LFS/usr/bin/make" --version >/dev/null
"$LFS/usr/bin/gcc" -dumpmachine | grep -Fx "$LFS_TGT" >/dev/null
test -s "$LFS/usr/lib/libncursesw.so"
test -x "$LFS/usr/bin/chroot"
test -f "$TOOLS/.glitchcore-binutils-pass2-complete"
test -f "$TOOLS/.glitchcore-gcc-pass2-complete"
touch "$TOOLS/.glitchcore-chapter6-complete"

log "LFS Chapter 6 temporary cross-tools completed and verified."
echo "Stages: M4, Ncurses, Bash, Coreutils, Diffutils, File, Findutils, Gawk, Grep, Gzip, Make, Patch, Sed, Tar, Xz, Binutils Pass 2, GCC Pass 2."
echo "This checkpoint is not yet a complete LFS system; Chapter 7 chroot tools remain."
