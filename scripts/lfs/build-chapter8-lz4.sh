#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == --check-only ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check-only] /absolute/LFS" >&2; exit 2; }
INPUT=$1 ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=lz4-1.10.0.tar.gz MARKER=.glitchcore-ch8-lz4-complete
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"; [[ "$LFS" != / ]] || fail "Refusing host root."
for p in sources tools etc usr/bin usr/lib dev proc sys run; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing/unsafe directory: $p"; done
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete .glitchcore-ch8-bzip2-complete .glitchcore-ch8-xz-complete; do [[ -f "$LFS/tools/$m" && ! -L "$LFS/tools/$m" ]] || fail "Missing checkpoint: $m"; done
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" && -x "$LFS/usr/bin/gcc" ]] || fail "Native LFS tools missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
tar -tzf "$LFS/sources/$ARCHIVE" > "$listing" || fail "Cannot read LZ4 archive."
grep -Fxq lz4-1.10.0/Makefile "$listing" || fail "Unexpected LZ4 archive layout."
grep -Fxq lz4-1.10.0/lib/Makefile "$listing" || fail "LZ4 library Makefile missing."
rm -f "$listing"; trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.9 LZ4 preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]] || fail "Requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath; do command -v "$c" >/dev/null || fail "Missing host command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "LZ4 already installed."; exit 0; }
for p in dev proc sys run; do mountpoint -q "$LFS/$p" && fail "Already mounted: $LFS/$p"; done
D=0 P=0 S=0 R=0
cleanup(){ local e=0; if ((R)); then umount "$LFS/run" && R=0 || e=1; fi; if ((S)); then umount "$LFS/sys" && S=0 || e=1; fi; if ((P)); then umount "$LFS/proc" && P=0 || e=1; fi; if ((D)); then umount "$LFS/dev" && D=0 || e=1; fi; return "$e"; }
finish(){ local s=$?; trap - EXIT; set +e; cleanup || s=1; exit "$s"; }
trap finish EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
mount --bind /dev "$LFS/dev"; D=1
mount -t proc proc "$LFS/proc"; P=1
mount -t sysfs sysfs "$LFS/sys"; S=1
mount -t tmpfs tmpfs "$LFS/run"; R=1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash --login -s <<'CHROOT'
set -Eeuo pipefail
cd /sources
[[ -s lz4-1.10.0.tar.gz && ! -L lz4-1.10.0.tar.gz ]] || { echo "Missing LZ4 source." >&2; exit 1; }
rm -rf lz4-1.10.0
tar -xf lz4-1.10.0.tar.gz
cd lz4-1.10.0
make BUILD_STATIC=no PREFIX=/usr
make -j1 check
make BUILD_STATIC=no PREFIX=/usr install
test -x /usr/bin/lz4
test -s /usr/lib/liblz4.so
test ! -e /usr/lib/liblz4.a
for app in lz4c lz4cat unlz4; do test -L "/usr/bin/$app"; done
printf 'GLITCHCORE LZ4 smoke test\n' > /tmp/glitchcore-lz4-test.txt
lz4 -f /tmp/glitchcore-lz4-test.txt
lz4 -d -f /tmp/glitchcore-lz4-test.txt.lz4
grep -Fxq 'GLITCHCORE LZ4 smoke test' /tmp/glitchcore-lz4-test.txt
rm -f /tmp/glitchcore-lz4-test.txt
echo "GLITCH//CORE LFS Chapter 8.9 LZ4 1.10.0: PASSED"
CHROOT
cleanup || fail "Could not unmount all LFS virtual filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.9 — LZ4 1.10.0"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "LZ4 MD5: $(awk '$2=="lz4-1.10.0.tar.gz"{print $1}' "$LFS/sources/md5sums")"
 echo "Status: LZ4 1.10.0 built, make -j1 check passed, installed and smoke-tested inside LFS chroot"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.9 LZ4 1.10.0: PASSED"
