#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 4 && "$(id -u)" -eq 0 ]] || { echo "Usage: sudo $0 WORK_ROOT ABS_ARCHIVE UID GID" >&2; exit 2; }
W="$(realpath -e "$1")"; A="$2"; U="$3"; G="$4"; L="$W/lfs"
[[ "$A" == /* && "$U" =~ ^[0-9]+$ && "$G" =~ ^[0-9]+$ ]] || exit 2
[[ -f "$L/tools/.glitchcore-chapter7-temporary-tools-complete" && -f "$L/tools/.glitchcore-ch8-man-pages-complete" && -s "$L/CHAPTER-8-BUILD-INFO.txt" ]] || { echo "Chapter 7/8 gates missing" >&2; exit 1; }
P="$(realpath -e "$(dirname "$A")")"; A="$P/$(basename "$A")"; [[ ! -e "$A" ]] || exit 1
tar --numeric-owner -czf "$A" -C "$W" LFS-VERSION lfs/sources lfs/tools lfs/usr lfs/bin lfs/lib lfs/sbin lfs/lib64 lfs/etc lfs/var lfs/home lfs/root lfs/tmp lfs/run lfs/dev lfs/proc lfs/sys lfs/boot lfs/mnt lfs/opt lfs/srv lfs/media lfs/CHAPTER-6-BUILD-INFO.txt lfs/CHAPTER-7-CHROOT-PREP-INFO.txt lfs/CHAPTER-7-BUILD-INFO.txt lfs/CHAPTER-8-BUILD-INFO.txt
tar -tzf "$A" >/dev/null
tar -tzf "$A" | grep -Fxq lfs/tools/.glitchcore-ch8-man-pages-complete
chown "$U:$G" "$A"; chmod 0644 "$A"; test -s "$A"
echo "Chapter 8.3 checkpoint packaged: $A"
