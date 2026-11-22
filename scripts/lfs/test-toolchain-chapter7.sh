#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-toolchain-chapter7.sh"
LOCK="$ROOT/config/lfs-toolchain.lock"
fail() { echo "ERROR: $*" >&2; exit 1; }

bash -n "$BUILDER" || fail "Chapter 7 builder has invalid Bash syntax."
grep -Fq 'gettext-1.0.tar.xz' "$BUILDER" || fail "Gettext recipe is missing."
grep -Fq 'Python-3.14.7.tar.xz' "$BUILDER" || fail "Pinned Python archive is missing."
grep -Fq 'util-linux-2.42.2.tar.xz' "$BUILDER" || fail "Pinned Util-linux archive is missing."
grep -Fq 'CHAPTER7_TEMPORARY_PACKAGES' "$LOCK" || fail "Chapter 7 package lock is missing."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
target="$tmp/lfs"
mkdir -p "$target"/{sources,tools,usr/bin,usr/sbin,usr/lib,dev/pts,dev/shm,proc,sys,run}
touch "$target/tools/.glitchcore-chapter6-complete"
touch "$target/tools/.glitchcore-chroot-ready"
cat > "$target/CHAPTER-7-CHROOT-PREP-INFO.txt" <<'EOF'
LFS_BOOK=13.1-systemd
TARGET=x86_64-lfs-linux-gnu
CHROOT_SMOKE=passed
PATH=/usr/bin:/usr/sbin
CHAPTER7_TEMPORARY_PACKAGES=not-built
EOF

packages="$(awk -F= '$1 == "CHAPTER7_TEMPORARY_PACKAGES" { sub(/^[^=]*=/, ""); print; count++ } END { if (count != 1) exit 1 }' "$LOCK")" \
  || fail "Chapter 7 source contract is missing or duplicated."
IFS=',' read -r -a archives <<< "$packages"
[[ "${#archives[@]}" -eq 8 ]] || fail "Expected eight Chapter 7 source archives."

for archive in "${archives[@]}"; do
  printf 'fixture archive: %s\n' "$archive" > "$target/sources/$archive"
  printf 'https://example.invalid/lfs/%s\n' "$archive" >> "$target/sources/wget-list"
  (cd "$target/sources" && md5sum -- "$archive") >> "$target/sources/md5sums"
done

bash "$BUILDER" --check-only "$target" >/dev/null || fail "Valid Chapter 7 preflight fixture was rejected."
[[ ! -e "$target/tools/.glitchcore-chapter7-temporary-tools-complete" ]] || fail "Check-only mode created a build completion marker."

missing="$tmp/missing-source"
cp -a "$target" "$missing"
rm "$missing/sources/${archives[0]}"
if bash "$BUILDER" --check-only "$missing" >/dev/null 2>&1; then
  fail "Preflight accepted a missing Chapter 7 source archive."
fi

bad_marker="$tmp/missing-marker"
cp -a "$target" "$bad_marker"
rm "$bad_marker/tools/.glitchcore-chroot-ready"
if bash "$BUILDER" --check-only "$bad_marker" >/dev/null 2>&1; then
  fail "Preflight accepted a rootfs without the chroot-ready marker."
fi

symlink_target="$tmp/symlink-target"
ln -s "$target" "$symlink_target"
if bash "$BUILDER" --check-only "$symlink_target" >/dev/null 2>&1; then
  fail "Preflight accepted a symlink as the selected rootfs."
fi

echo "LFS Chapter 7 temporary-tools builder preflight tests: OK"
echo "NOTE: these tests validate guards and source contracts; the workflow performs the real chroot builds."
