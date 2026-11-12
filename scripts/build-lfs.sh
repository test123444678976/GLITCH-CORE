#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE - LFS 13.1 systemd preparation
# Downloads and verifies the official LFS systemd source set.
# This stage does NOT compile LFS or replace the rescue ISO.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work-lfs"
LFS="$WORK/lfs"
SOURCES="$LFS/sources"

LFS_VERSION="13.1"
LFS_BASE_URL="https://www.linuxfromscratch.org/lfs/downloads/stable-systemd"

echo "======================================"
echo " GLITCH//CORE - LFS ${LFS_VERSION}-systemd"
echo " Source preparation"
echo "======================================"

REQUIRED_TOOLS=(
    bash wget md5sum tar xz make gcc g++ awk bison perl
    python3 patch diff find file grep sed
)

echo "==> Checking host tools"
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Missing host tool: $tool"
        exit 1
    fi
done
echo "==> Host tools available"

echo "==> Creating LFS workspace"
mkdir -p "$SOURCES"
chmod a+wt "$SOURCES"

echo "==> Downloading official LFS systemd manifests"
wget -q --https-only "$LFS_BASE_URL/wget-list" -O "$SOURCES/wget-list"
wget -q --https-only "$LFS_BASE_URL/md5sums" -O "$SOURCES/md5sums"

test -s "$SOURCES/wget-list"
test -s "$SOURCES/md5sums"

# Fail closed if the endpoint ever serves a manifest for another LFS release.
for package in binutils-2.47 gcc-16.2.0; do
    if ! grep -q "$package" "$SOURCES/wget-list" ||
       ! grep -q "$package" "$SOURCES/md5sums"; then
        echo "ERROR: LFS 13.1-systemd manifest is missing expected package: $package"
        echo "Refusing to download a mismatched source set."
        exit 1
    fi
done

# LFS 13.1-systemd uses systemd, not the legacy System V bootscripts package.
# Some mirrored/stale manifests may still list this archive under /13.1/,
# where it is not published. Remove that obsolete entry from BOTH manifests
# so it is neither downloaded nor expected by the checksum verification.
if grep -qi 'lfs-bootscripts-' "$SOURCES/wget-list" ||
   grep -qi 'lfs-bootscripts-' "$SOURCES/md5sums"; then
    echo "==> Excluding legacy System V LFS-Bootscripts entry (not used by systemd)"
    sed -i '/lfs-bootscripts-/Id' "$SOURCES/wget-list" "$SOURCES/md5sums"
fi

if grep -qi 'lfs-bootscripts-' "$SOURCES/wget-list" ||
   grep -qi 'lfs-bootscripts-' "$SOURCES/md5sums"; then
    echo "ERROR: Obsolete LFS-Bootscripts entry remains in the manifests."
    exit 1
fi

echo "==> Downloading LFS 13.1-systemd source packages"
download_status=0
wget --https-only --continue --tries=3 \
    --input-file="$SOURCES/wget-list" \
    --directory-prefix="$SOURCES" || download_status=$?

if [[ "$download_status" -ne 0 ]]; then
    echo "WARNING: one or more primary source downloads failed (wget exit $download_status)."
    echo "==> Checking the ncurses 6.6 HTTPS mirror fallback before the full checksum audit"
fi
bash "$ROOT/scripts/lfs/ensure-ncurses-source.sh" "$SOURCES"

echo "==> Verifying official MD5 checksums"
(
    cd "$SOURCES"
    md5sum -c md5sums
)

cat > "$WORK/LFS-VERSION" <<EOF
GLITCH//CORE LFS
LFS_VERSION=${LFS_VERSION}-systemd
SOURCE=${LFS_BASE_URL}
EOF

echo
echo "======================================"
echo " LFS SOURCE PREPARATION COMPLETED"
echo "======================================"
echo "Workspace: $LFS"
echo "Sources:   $SOURCES"
echo "All listed LFS 13.1-systemd source checksums passed."
