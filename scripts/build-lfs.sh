
#!/usr/bin/env bash
set -Eeuo pipefail

# GLITCH//CORE - LFS 13.1 systemd preparation
# This stage downloads and verifies official LFS sources.
# It does NOT replace the existing rescue build.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work-lfs"
LFS="$WORK/lfs"
SOURCES="$LFS/sources"

LFS_VERSION="13.1"
LFS_BASE_URL="https://www.linuxfromscratch.org/lfs/downloads/stable-systemd"

echo "======================================"
echo " GLITCH//CORE - LFS ${LFS_VERSION}"
echo " Source preparation"
echo "======================================"

# Check required host commands
REQUIRED_TOOLS=(
    bash
    wget
    md5sum
    tar
    xz
    make
    gcc
    g++
    awk
    bison
    perl
    python3
    patch
    diff
    find
    file
)

echo "==> Checking host tools"

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Missing host tool: $tool"
        exit 1
    fi
done

echo "==> Host tools available"

# Create isolated LFS workspace
echo "==> Creating LFS workspace"

mkdir -p "$SOURCES"
chmod a+wt "$SOURCES"

# Download official LFS source manifests
echo "==> Downloading official LFS manifests"

wget -q --https-only \
    "$LFS_BASE_URL/wget-list" \
    -O "$SOURCES/wget-list"

wget -q --https-only \
    "$LFS_BASE_URL/md5sums" \
    -O "$SOURCES/md5sums"

test -s "$SOURCES/wget-list"
test -s "$SOURCES/md5sums"

# Download all official LFS source archives and patches
echo "==> Downloading LFS source packages"

wget \
    --continue \
    --tries=3 \
    --input-file="$SOURCES/wget-list" \
    --directory-prefix="$SOURCES"

# Verify downloaded sources
echo "==> Verifying MD5 checksums"

(
    cd "$SOURCES"
    md5sum -c md5sums
)

# Record build information
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
echo
echo "All official LFS source checksums passed."
