#!/usr/bin/env bash
set -Eeuo pipefail

# Build Mesa natively inside a completed x86_64 LFS target rootfs.
# This is deliberately NOT a host DESTDIR build: all headers, libraries,
# pkg-config metadata and runtime dependencies come from the selected LFS root.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/config/graphics-sources.lock"
TARGET_INPUT="${1:-}"
SOURCES_INPUT="${2:-$ROOT/work-lfs/graphics-sources}"
BUILD_JOBS="${JOBS:-2}"
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "Requires a Linux x86_64 build host."
[[ "$(id -u)" -eq 0 ]] || fail "Run this rootfs-chroot builder as root (for chroot only)."
[[ -n "$TARGET_INPUT" && "$TARGET_INPUT" == /* ]] || fail "Usage: $0 /absolute/path/to/LFS-rootfs [verified-source-dir]"
[[ -d "$TARGET_INPUT" ]] || fail "Target rootfs does not exist."
TARGET="$(realpath -e "$TARGET_INPUT")"
[[ "$TARGET" != "/" ]] || fail "Refusing to build into the host root."
[[ -x "$TARGET/bin/bash" && -x "$TARGET/usr/bin/env" ]] || fail "Target is not a bootstrapped LFS rootfs."
[[ -x "$TARGET/usr/bin/meson" && -x "$TARGET/usr/bin/ninja" ]] || fail "Meson and Ninja must first be installed inside the LFS target."
[[ -x "$TARGET/usr/bin/python3" && -x "$TARGET/usr/bin/pkg-config" ]] || fail "Python 3 and pkg-config must first be installed inside the LFS target."
[[ -f "$TARGET/usr/include/xf86drm.h" && -e "$TARGET/usr/lib/libdrm.so" ]] || fail "Target libdrm development files are missing."
[[ -x "$TARGET/usr/bin/ldconfig" ]] || fail "Target ldconfig is missing."

bash "$ROOT/scripts/lfs/validate-graphics-sources.sh" "$LOCK"
entry="$(awk -F'|' '$1=="mesa"{print; n++} END{if(n!=1)exit 1}' "$LOCK")" || fail "Mesa source pin missing or duplicated."
IFS='|' read -r name version archive url checksum <<< "$entry"
SOURCES="$(realpath -e "$SOURCES_INPUT")"
[[ -f "$SOURCES/$archive" && ! -L "$SOURCES/$archive" ]] || fail "Verified Mesa archive missing: $SOURCES/$archive"
printf '%s  %s\n' "$checksum" "$SOURCES/$archive" | sha256sum --check --status || fail "Mesa source checksum mismatch."
[[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."

# Keep the archive and build tree inside the target so the compiler resolves
# only target headers/libraries and never accidentally links to the host.
install -d -m 0755 "$TARGET/sources"
install -m 0644 "$SOURCES/$archive" "$TARGET/sources/$archive"
chroot "$TARGET" /usr/bin/env -i HOME=/root TERM="${TERM:-dumb}" PATH=/usr/bin:/bin \
  MESA_VERSION="$version" MESA_ARCHIVE="$archive" MESA_JOBS="$BUILD_JOBS" MESA_SHA256="$checksum" \
  /bin/bash -euxc '
    cd /sources
    rm -rf "mesa-$MESA_VERSION" "mesa-build"
    tar -xf "$MESA_ARCHIVE"
    test -f "mesa-$MESA_VERSION/meson.build"
    meson setup "mesa-build" "mesa-$MESA_VERSION" \
      --prefix=/usr --buildtype=release \
      -Dplatforms=x11,wayland \
      -Dgallium-drivers=softpipe,virgl \
      -Dvulkan-drivers= \
      -Dllvm=disabled \
      -Dglx=dri -Degl=enabled -Dgbm=enabled \
      -Dopengl=true -Dgles1=disabled -Dgles2=enabled \
      -Dshared-glapi=enabled
    meson compile -C mesa-build --jobs "$MESA_JOBS"
    meson install -C mesa-build
    /usr/bin/ldconfig
    test -e /usr/lib/libGL.so.1
    test -e /usr/lib/libEGL.so.1
    test -e /usr/lib/libgbm.so.1
    test -d /usr/lib/dri
    test -e /usr/lib/dri/swrast_dri.so
    test -e /usr/lib/dri/virtio_gpu_dri.so
    install -d -m 0755 /usr/share/glitch-core
    printf "package=mesa\\nversion=%s\\nsource_sha256=%s\\ninstall_mode=LFS-chroot\\n" \
      "$MESA_VERSION" "$MESA_SHA256" > /usr/share/glitch-core/mesa-build-info
    touch /var/lib/glitch-core-mesa-installed
  '

echo "Mesa $version built and installed inside the LFS target rootfs: $TARGET"
echo "This does not yet prove Xorg starts or MATE can create a graphical session."
