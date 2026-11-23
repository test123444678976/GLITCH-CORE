#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == "--check-only" ]]; then CHECK_ONLY=1; shift; fi
[[ $# -eq 1 ]] || { echo "Usage: $0 [--check-only] /absolute/path/to/LFS" >&2; exit 2; }
INPUT="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=man-pages-6.18.tar.xz
MARKER=.glitchcore-ch8-man-pages-complete
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"
[[ "$LFS" != / ]] || fail "Refusing host root."
for p in sources tools usr/bin usr/share; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing directory: $p"; done
[[ -f "$LFS/tools/.glitchcore-chapter7-temporary-tools-complete" ]] || fail "Chapter 7 checkpoint is not complete."
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/make" ]] || fail "Chapter 7 bash/make are missing."
[[ -L "$LFS/bin" && "$(readlink "$LFS/bin")" == usr/bin ]] || fail "Unexpected merged-/usr layout."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
listing="$(mktemp)"
trap 'rm -f "$listing"' EXIT
if ! tar -tJf "$LFS/sources/$ARCHIVE" >"$listing"; then rm -f "$listing"; fail "Cannot read Man-pages source archive."; fi
grep -Fq 'man-pages-6.18/' "$listing" || { rm -f "$listing"; fail "Unexpected Man-pages archive layout."; }
rm -f "$listing"
trap - EXIT
if (( CHECK_ONLY )); then echo "Chapter 8.3 Man-pages preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" -eq 0 ]] || fail "Build requires root on Linux x86_64."
for c in mount umount mountpoint chroot realpath tar sha256sum find; do command -v "$c" >/dev/null || fail "Missing command: $c"; done
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "Man-pages already installed."; exit 0; }
for p in dev proc sys run; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing mountpoint $p"; mountpoint -q "$LFS/$p" && fail "Already mounted: $p"; done
rm -rf "$LFS/sources/man-pages-6.18"
tar -xf "$LFS/sources/$ARCHIVE" -C "$LFS/sources"
[[ -d "$LFS/sources/man-pages-6.18" && ! -L "$LFS/sources/man-pages-6.18" ]] || fail "Source extraction failed."
chown -hR root:root "$LFS/sources/man-pages-6.18"
D=0 P=0 S=0 R=0
cleanup(){
 local e=0
 if (( R )); then umount "$LFS/run" && R=0 || e=1; fi
 if (( S )); then umount "$LFS/sys" && S=0 || e=1; fi
 if (( P )); then umount "$LFS/proc" && P=0 || e=1; fi
 if (( D )); then umount "$LFS/dev" && D=0 || e=1; fi
 return "$e"
}
finish(){ local s=$?; trap - EXIT; set +e; cleanup || s=1; exit "$s"; }
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mount --bind /dev "$LFS/dev"; D=1
mount -t proc proc "$LFS/proc"; P=1
mount -t sysfs sysfs "$LFS/sys"; S=1
mount -t tmpfs tmpfs "$LFS/run"; R=1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash --login -c '
 set -Eeuo pipefail
 cd /sources/man-pages-6.18
 shopt -s nullglob
 crypt_pages=(man3/crypt*)
 (("${#crypt_pages[@]}" >= 1)) || { echo "crypt man pages missing" >&2; exit 1; }
 rm -fv "${crypt_pages[@]}"
 make -R GIT=false prefix=/usr install
'
COUNT="$(find "$LFS/usr/share/man" -type f | wc -l)"
[[ "$COUNT" -ge 1000 ]] || fail "Only $COUNT manual files installed."
cleanup || fail "Could not unmount chroot filesystems."
trap - EXIT INT TERM
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.3 — Man-pages 6.18"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "Source SHA256: $(sha256sum "$LFS/sources/$ARCHIVE" | awk '{print $1}')"
 echo "Installed manual files: $COUNT"
 echo "Status: Man-pages 6.18 installed and verified inside LFS chroot"
} > "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.3 Man-pages 6.18: PASSED"
