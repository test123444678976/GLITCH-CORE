#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -ge 4 && $# -le 5 && "$(id -u)" -eq 0 ]] || { echo "Usage: sudo $0 WORK_ROOT ABS_ARCHIVE UID GID [CHAPTER8_MARKER]" >&2; exit 2; }
W="$(realpath -e "$1")"; A="$2"; U="$3"; G="$4"; L="$W/lfs"
MARKER="${5:-.glitchcore-ch8-man-pages-complete}"
[[ "$A" == /* && "$U" =~ ^[0-9]+$ && "$G" =~ ^[0-9]+$ ]] || exit 2
[[ "$MARKER" =~ ^\.glitchcore-ch8-[a-z0-9-]+-complete$ ]] || { echo "Unsafe Chapter 8 marker" >&2; exit 2; }
[[ -f "$L/tools/.glitchcore-chapter7-temporary-tools-complete" && -f "$L/tools/.glitchcore-ch8-man-pages-complete" && -f "$L/tools/$MARKER" && -s "$L/CHAPTER-8-BUILD-INFO.txt" ]] || { echo "Chapter 7/8 gates missing" >&2; exit 1; }
P="$(realpath -e "$(dirname "$A")")"; A="$P/$(basename "$A")"; [[ ! -e "$A" ]] || exit 1
tar --numeric-owner -czf "$A" -C "$W" LFS-VERSION lfs/sources lfs/tools lfs/usr lfs/bin lfs/lib lfs/sbin lfs/lib64 lfs/etc lfs/var lfs/home lfs/root lfs/tmp lfs/run lfs/dev lfs/proc lfs/sys lfs/boot lfs/mnt lfs/opt lfs/srv lfs/media lfs/CHAPTER-6-BUILD-INFO.txt lfs/CHAPTER-7-CHROOT-PREP-INFO.txt lfs/CHAPTER-7-BUILD-INFO.txt lfs/CHAPTER-8-BUILD-INFO.txt
listing="$(mktemp)"
trap 'rm -f "$listing"' EXIT
tar -tzf "$A" > "$listing"
grep -Fxq "lfs/tools/$MARKER" "$listing"
rm -f "$listing"
trap - EXIT
chown "$U:$G" "$A"; chmod 0644 "$A"; test -s "$A"
echo "Chapter 8 checkpoint packaged ($MARKER): $A"
