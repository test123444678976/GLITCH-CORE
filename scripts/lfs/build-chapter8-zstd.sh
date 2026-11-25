#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == --check-only ]]; then CHECK_ONLY=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--check-only] /absolute/LFS" >&2; exit 2; }
INPUT=$1 ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=zstd-1.5.7.tar.gz MARKER=.glitchcore-ch8-zstd-complete
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"; [[ "$LFS" != / ]] || fail "Refusing host root."
for p in sources tools etc usr/bin usr/lib dev proc sys run; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing/unsafe directory: $p"; done
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete .glitchcore-ch8-bzip2-complete .glitchcore-ch8-xz-complete .glitchcore-ch8-lz4-complete; do [[ -f "$LFS/tools/$m" && ! -L "$LFS/tools/$m" ]] || fail "Missing checkpoint: $m"; done
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" && -x "$LFS/usr/bin/gcc" ]] || fail "Native LFS tools missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
listing="$(mktemp)"; trap 'rm -f "$listing"' EXIT
tar -tzf "$LFS/sources/$ARCHIVE" > "$listing" || fail "Cannot read Zstd archive."
grep -Eq '^zstd-1\.5\.7/(build/cmake/CMakeLists\.txt|Makefile)$' "$listing" || fail "Unexpected Zstd archive layout."
rm -f "$listing"; trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.10 Zstd preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" == 0 ]] || fail "Requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath; do command -v "$c" >/dev/null || fail "Missing host command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "Zstd already installed."; exit 0; }
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
[[ -s zstd-1.5.7.tar.gz && ! -L zstd-1.5.7.tar.gz ]] || { echo "Missing Zstd source." >&2; exit 1; }
rm -rf zstd-1.5.7
tar -xf zstd-1.5.7.tar.gz
cd zstd-1.5.7
make prefix=/usr
make check
make prefix=/usr install
rm -v /usr/lib/libzstd.a
test -x /usr/bin/zstd
test -s /usr/lib/libzstd.so
test ! -e /usr/lib/libzstd.a
for app in zstdcat zstdmt unzstd; do test -L "/usr/bin/$app"; done
test -x /usr/bin/zstdgrep
test -x /usr/bin/zstdless
printf 'GLITCHCORE Zstandard smoke test\n' > /tmp/glitchcore-zstd-test.txt
zstd -f /tmp/glitchcore-zstd-test.txt
zstd -d -f /tmp/glitchcore-zstd-test.txt.zst
grep -Fxq 'GLITCHCORE Zstandard smoke test' /tmp/glitchcore-zstd-test.txt
rm -f /tmp/glitchcore-zstd-test.txt
echo "GLITCH//CORE LFS Chapter 8.10 Zstd 1.5.7: PASSED"
CHROOT
cleanup || fail "Could not unmount all LFS virtual filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.10 — Zstd 1.5.7"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "Zstd MD5: $(awk '$2=="zstd-1.5.7.tar.gz"{print $1}' "$LFS/sources/md5sums")"
 echo "Status: Zstd 1.5.7 built, make check passed, installed and smoke-tested inside LFS chroot"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.10 Zstd 1.5.7: PASSED"
