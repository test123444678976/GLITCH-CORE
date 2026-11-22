#!/usr/bin/env bash
set -Eeuo pipefail

# Package the Chapter 7 rootfs as root so private files and ownership metadata
# are preserved. The resulting archive is handed back to the unprivileged CI
# account for actions/upload-artifact.
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $# -eq 4 ]] || fail "Usage: $0 WORK_ROOT ABSOLUTE_ARCHIVE_PATH OWNER_UID OWNER_GID"
WORK_ROOT_INPUT="$1"
ARCHIVE_INPUT="$2"
OWNER_UID="$3"
OWNER_GID="$4"

[[ "$(id -u)" -eq 0 ]] || fail "Run checkpoint packaging as root."
[[ "$WORK_ROOT_INPUT" == /* && -d "$WORK_ROOT_INPUT" ]] || fail "WORK_ROOT must be an existing absolute directory."
[[ "$ARCHIVE_INPUT" == /* ]] || fail "Archive path must be absolute."
[[ "$OWNER_UID" =~ ^[0-9]+$ && "$OWNER_GID" =~ ^[0-9]+$ ]] || fail "Archive owner must use numeric UID and GID."

WORK_ROOT="$(realpath -e -- "$WORK_ROOT_INPUT")"
[[ "$WORK_ROOT" != "/" ]] || fail "Refusing to package from the host root."
ROOTFS="$WORK_ROOT/lfs"
[[ -d "$ROOTFS" && ! -L "$ROOTFS" ]] || fail "Expected an ordinary LFS rootfs at $ROOTFS."
[[ -s "$WORK_ROOT/LFS-VERSION" && ! -L "$WORK_ROOT/LFS-VERSION" ]] || fail "Verified LFS version marker is missing."
[[ -f "$ROOTFS/tools/.glitchcore-chapter6-complete" ]] || fail "Chapter 6 completion marker is missing."
[[ -f "$ROOTFS/tools/.glitchcore-chroot-ready" ]] || fail "Chapter 7 chroot-ready marker is missing."
[[ -f "$ROOTFS/CHAPTER-6-BUILD-INFO.txt" ]] || fail "Chapter 6 provenance is missing."
[[ -f "$ROOTFS/CHAPTER-7-CHROOT-PREP-INFO.txt" ]] || fail "Chapter 7 preparation provenance is missing."
grep -Fxq "CHROOT_SMOKE=passed" "$ROOTFS/CHAPTER-7-CHROOT-PREP-INFO.txt" || fail "Chapter 7 chroot smoke test is not recorded as passed."

ARCHIVE_PARENT_INPUT="$(dirname -- "$ARCHIVE_INPUT")"
[[ -d "$ARCHIVE_PARENT_INPUT" ]] || fail "Archive parent directory does not exist."
ARCHIVE_PARENT="$(realpath -e -- "$ARCHIVE_PARENT_INPUT")"
ARCHIVE="$ARCHIVE_PARENT/$(basename -- "$ARCHIVE_INPUT")"
[[ ! -e "$ARCHIVE" && ! -L "$ARCHIVE" ]] || fail "Refusing to overwrite an existing archive."
case "$ARCHIVE/" in
  "$ROOTFS/"*) fail "Archive must be outside the target rootfs." ;;
esac

FILES=(
  LFS-VERSION
  lfs/sources lfs/tools lfs/usr lfs/bin lfs/lib lfs/sbin lfs/lib64
  lfs/etc lfs/var lfs/home lfs/root lfs/tmp lfs/run lfs/dev lfs/proc lfs/sys
  lfs/boot lfs/mnt lfs/opt lfs/srv lfs/media
  lfs/CHAPTER-6-BUILD-INFO.txt lfs/CHAPTER-7-CHROOT-PREP-INFO.txt
)

# The bootstrap checkpoint is valid before Chapter 7 packages are built.
# Once the final marker exists, provenance becomes mandatory and is included.
if [[ -f "$ROOTFS/tools/.glitchcore-chapter7-temporary-tools-complete" ]]; then
  [[ -s "$ROOTFS/CHAPTER-7-BUILD-INFO.txt" ]] || fail "Chapter 7 build marker exists but build provenance is missing."
  FILES+=(lfs/CHAPTER-7-BUILD-INFO.txt)
fi

umask 022
tar --numeric-owner -czf "$ARCHIVE" -C "$WORK_ROOT" "${FILES[@]}"

tar -tzf "$ARCHIVE" >/dev/null
test -s "$ARCHIVE"
chown -- "$OWNER_UID:$OWNER_GID" "$ARCHIVE"
chmod 0644 "$ARCHIVE"

echo "Chapter 7 checkpoint packaged with numeric ownership and Unix permissions."
echo "Archive: $ARCHIVE"
echo "Archive owner: $OWNER_UID:$OWNER_GID"
echo "The checkpoint is a CI build artifact, not a bootable final system."
