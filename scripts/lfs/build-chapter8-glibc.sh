#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == --check-only ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check-only] /absolute/LFS" >&2; exit 2; }
INPUT=$1 ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=glibc-2.44.tar.xz FHS=glibc-fhs-1.patch FIXES=glibc-2.44-upstream_fixes-1.patch
MARKER=.glitchcore-ch8-glibc-complete JOBS="${JOBS:-2}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"; [[ "$LFS" != / ]] || fail "Refusing host root."
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be positive."
for p in sources tools etc usr/bin usr/share dev proc sys run; do
  [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing/unsafe directory: $p"
done
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete; do
  [[ -f "$LFS/tools/$m" && ! -L "$LFS/tools/$m" ]] || fail "Missing checkpoint: $m"
done
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" && -x "$LFS/usr/bin/gcc" ]] || fail "Native LFS tools missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
for f in "$ARCHIVE" "$FHS" "$FIXES"; do bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$f" >/dev/null; done
listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
tar -tJf "$LFS/sources/$ARCHIVE" > "$listing" || fail "Cannot read Glibc archive."
grep -Fxq glibc-2.44/Makefile "$listing" || fail "Unexpected Glibc archive layout."
grep -Fxq glibc-2.44/configure "$listing" || fail "Glibc configure script missing."
rm -f "$listing"; trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.5 Glibc preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]] || fail "Requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath sha256sum; do command -v "$c" >/dev/null || fail "Missing host command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "Glibc already installed."; exit 0; }
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
for f in glibc-2.44.tar.xz glibc-fhs-1.patch glibc-2.44-upstream_fixes-1.patch; do [[ -s "$f" && ! -L "$f" ]] || { echo "Missing source: $f" >&2; exit 1; }; done
rm -rf glibc-2.44
tar -xf glibc-2.44.tar.xz
cd glibc-2.44
patch -Np1 -i ../glibc-fhs-1.patch
patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch
mkdir -p build && cd build
../configure --prefix=/usr --disable-werror --disable-nscd libc_cv_slibdir=/usr/lib --enable-stack-protector=strong --enable-kernel=5.10
make -j"$JOBS"
# LFS treats this test suite as critical: no install/checkpoint on failure.
if ! make check > /sources/glibc-2.44-make-check.log 2>&1; then
  tail -n 160 /sources/glibc-2.44-make-check.log >&2 || true
  echo "Glibc make check failed; installation stopped." >&2
  exit 1
fi
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
localedef -i C -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i pt_PT -f UTF-8 pt_PT.UTF-8
cat > /etc/nsswitch.conf <<'EOF'
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
EOF
mkdir -p /etc/ld.so.conf.d
cat > /etc/ld.so.conf <<'EOF'
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
EOF
/usr/bin/getent passwd root >/dev/null
/usr/bin/ldconfig
test -s /usr/lib/libc.so.6
test -x /usr/bin/ldconfig
test -x /usr/bin/localedef
/usr/bin/ldd --version >/dev/null
echo "GLITCH//CORE LFS Chapter 8.5 Glibc 2.44: PASSED"
CHROOT
cleanup || fail "Could not unmount all LFS virtual filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.5 — Glibc 2.44"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "JOBS: $JOBS"
 echo "Glibc SHA256: $(sha256sum "$LFS/sources/$ARCHIVE" | awk '{print $1}')"
 echo "FHS patch SHA256: $(sha256sum "$LFS/sources/$FHS" | awk '{print $1}')"
 echo "Upstream fixes SHA256: $(sha256sum "$LFS/sources/$FIXES" | awk '{print $1}')"
 echo "Test log: /sources/glibc-2.44-make-check.log"
 echo "Status: Glibc 2.44 built, make check passed, installed and verified inside LFS chroot"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.5 Glibc 2.44: PASSED"
