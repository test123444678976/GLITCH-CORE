#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == --check-only ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check-only] /absolute/LFS" >&2; exit 2; }
INPUT=$1 ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=bzip2-1.0.8.tar.gz PATCH=bzip2-1.0.8-install_docs-1.patch
MARKER=.glitchcore-ch8-bzip2-complete JOBS="${JOBS:-2}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"; [[ "$LFS" != / ]] || fail "Refusing host root."
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be positive."
for p in sources tools etc usr/bin usr/lib dev proc sys run; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing/unsafe directory: $p"; done
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete; do [[ -f "$LFS/tools/$m" && ! -L "$LFS/tools/$m" ]] || fail "Missing checkpoint: $m"; done
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" && -x "$LFS/usr/bin/gcc" ]] || fail "Native LFS tools missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$PATCH" >/dev/null
listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
tar -tzf "$LFS/sources/$ARCHIVE" > "$listing" || fail "Cannot read Bzip2 archive."
grep -Fxq bzip2-1.0.8/Makefile "$listing" || fail "Unexpected Bzip2 archive layout."
grep -Fxq bzip2-1.0.8/Makefile-libbz2_so "$listing" || fail "Shared-library Makefile missing."
rm -f "$listing"; trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.7 Bzip2 preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]] || fail "Requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath sha256sum; do command -v "$c" >/dev/null || fail "Missing host command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "Bzip2 already installed."; exit 0; }
for p in dev proc sys run; do mountpoint -q "$LFS/$p" && fail "Already mounted: $LFS/$p"; done
D=0 P=0 S=0 R=0
cleanup(){ local e=0; if ((R)); then umount "$LFS/run" && R=0 || e=1; fi; if ((S)); then umount "$LFS/sys" && S=0 || e=1; fi; if ((P)); then umount "$LFS/proc" && P=0 || e=1; fi; if ((D)); then umount "$LFS/dev" && D=0 || e=1; fi; return "$e"; }
finish(){ local s=$?; trap - EXIT; set +e; cleanup || s=1; exit "$s"; }
trap finish EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
mount --bind /dev "$LFS/dev"; D=1
mount -t proc proc "$LFS/proc"; P=1
mount -t sysfs sysfs "$LFS/sys"; S=1
mount -t tmpfs tmpfs "$LFS/run"; R=1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX JOBS="$JOBS" /bin/bash --login -s <<'CHROOT'
set -Eeuo pipefail
cd /sources
[[ -s bzip2-1.0.8.tar.gz && ! -L bzip2-1.0.8.tar.gz ]] || { echo "Missing Bzip2 source." >&2; exit 1; }
[[ -s bzip2-1.0.8-install_docs-1.patch && ! -L bzip2-1.0.8-install_docs-1.patch ]] || { echo "Missing Bzip2 documentation patch." >&2; exit 1; }
rm -rf bzip2-1.0.8
tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i 's@(PREFIX)/man@(PREFIX)/share/man@g' Makefile
make -f Makefile-libbz2_so
make clean
make -j"$JOBS"
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib/
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
cp -v bzip2-shared /usr/bin/bzip2
ln -sfv bzip2 /usr/bin/bzcat
ln -sfv bzip2 /usr/bin/bunzip2
rm -fv /usr/lib/libbz2.a
printf 'GLITCHCORE bzip2 smoke test\n' > /tmp/glitchcore-bzip2-test.txt
bzip2 -f /tmp/glitchcore-bzip2-test.txt
bzip2 -d -f /tmp/glitchcore-bzip2-test.txt.bz2
grep -Fxq 'GLITCHCORE bzip2 smoke test' /tmp/glitchcore-bzip2-test.txt
rm -f /tmp/glitchcore-bzip2-test.txt
test -s /usr/lib/libbz2.so.1.0.8
test -L /usr/lib/libbz2.so
test -L /usr/lib/libbz2.so.1
test -x /usr/bin/bzip2
test -s /usr/share/man/man1/bzip2.1
test -d /usr/share/doc/bzip2-1.0.8
echo "GLITCH//CORE LFS Chapter 8.7 Bzip2 1.0.8: PASSED"
CHROOT
cleanup || fail "Could not unmount all LFS virtual filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.7 — Bzip2 1.0.8"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "JOBS: $JOBS"
 echo "Bzip2 MD5: $(awk '$2=="bzip2-1.0.8.tar.gz"{print $1}' "$LFS/sources/md5sums")"
 echo "Documentation patch MD5: $(awk '$2=="bzip2-1.0.8-install_docs-1.patch"{print $1}' "$LFS/sources/md5sums")"
 echo "Status: Bzip2 1.0.8 built, smoke-tested and installed inside LFS chroot"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.7 Bzip2 1.0.8: PASSED"
