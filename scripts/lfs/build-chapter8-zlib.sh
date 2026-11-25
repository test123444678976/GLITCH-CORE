#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "\${1:-}" == --check-only ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check-only] /absolute/LFS" >&2; exit 2; }
INPUT=$1 ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=zlib-1.3.2.tar.gz MARKER=.glitchcore-ch8-zlib-complete JOBS="\${JOBS:-2}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"; [[ "$LFS" != / ]] || fail "Refusing host root."
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be positive."
for p in sources tools etc usr/bin usr/lib dev proc sys run; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing/unsafe directory: $p"; done
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete; do [[ -f "$LFS/tools/$m" && ! -L "$LFS/tools/$m" ]] || fail "Missing checkpoint: $m"; done
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" && -x "$LFS/usr/bin/gcc" ]] || fail "Native LFS tools missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
tar -tzf "$LFS/sources/$ARCHIVE" > "$listing" || fail "Cannot read Zlib archive."
grep -Fxq zlib-1.3.2/Makefile "$listing" || fail "Unexpected Zlib archive layout."
grep -Fxq zlib-1.3.2/configure "$listing" || fail "Zlib configure script missing."
rm -f "$listing"; trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.6 Zlib preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]] || fail "Requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath sha256sum; do command -v "$c" >/dev/null || fail "Missing host command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "Zlib already installed."; exit 0; }
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
[[ -s zlib-1.3.2.tar.gz && ! -L zlib-1.3.2.tar.gz ]] || { echo "Missing Zlib source." >&2; exit 1; }
rm -rf zlib-1.3.2
tar -xf zlib-1.3.2.tar.gz
cd zlib-1.3.2
./configure --prefix=/usr
make -j"$JOBS"
if ! make check > /sources/zlib-1.3.2-make-check.log 2>&1; then
  tail -n 120 /sources/zlib-1.3.2-make-check.log >&2 || true
  echo "Zlib make check failed; installation stopped." >&2
  exit 1
fi
make install
rm -fv /usr/lib/libz.a
test -s /usr/lib/libz.so
test -s /usr/include/zlib.h
test -s /usr/lib/pkgconfig/zlib.pc
echo "GLITCH//CORE LFS Chapter 8.6 Zlib 1.3.2: PASSED"
CHROOT
cleanup || fail "Could not unmount all LFS virtual filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.6 — Zlib 1.3.2"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "JOBS: $JOBS"
 echo "Zlib MD5 (official LFS manifest): $(awk '$2=="zlib-1.3.2.tar.gz"{print $1}' "$LFS/sources/md5sums")"
 echo "Test log: /sources/zlib-1.3.2-make-check.log"
 echo "Status: Zlib 1.3.2 built, make check passed, installed and verified inside LFS chroot"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.6 Zlib 1.3.2: PASSED"
