#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
DIST="$ROOT/dist"
ROOTFS="$WORK/rootfs"

KERNEL_VERSION="7.3.1"
BUSYBOX_VERSION="1.36.1"

mkdir -p "$WORK" "$DIST"

rm -rf "$WORK/linux" "$WORK/busybox" "$ROOTFS" "$WORK/iso"
rm -f "$DIST/GLITCH-CORE.iso"

echo "==> Downloading Linux ${KERNEL_VERSION}"

wget -q "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${KERNEL_VERSION}.tar.xz" \
    -O "$WORK/linux.tar.xz"

tar -xf "$WORK/linux.tar.xz" -C "$WORK"
mv "$WORK/linux-${KERNEL_VERSION}" "$WORK/linux"

echo "==> Configuring Linux kernel"

make -C "$WORK/linux" defconfig

make -C "$WORK/linux" olddefconfig

echo "==> Building Linux kernel"

make -C "$WORK/linux" -j"$(nproc)" bzImage

echo "==> Downloading BusyBox ${BUSYBOX_VERSION}"

wget -q "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" \
    -O "$WORK/busybox.tar.bz2"

tar -xf "$WORK/busybox.tar.bz2" -C "$WORK"
mv "$WORK/busybox-${BUSYBOX_VERSION}" "$WORK/busybox"

echo "==> Configuring static BusyBox"

make -C "$WORK/busybox" defconfig

sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' \
    "$WORK/busybox/.config"

grep -q '^CONFIG_STATIC=y' "$WORK/busybox/.config" || {
    echo "ERROR: BusyBox static configuration failed"
    exit 1
}

echo "==> Building BusyBox"

echo "==> Building BusyBox (diagnostic mode)"

if make -C "$WORK/busybox" -j1 V=1 2>&1 | tee "$WORK/busybox-build.log"; then
    echo "==> BusyBox compilation successful"
else
    STATUS=$?

    echo "ERROR: BusyBox compilation failed!"
    echo "==> Relevant errors:"

    grep -n -E 'error:|Error [0-9]|undefined reference|fatal error' \
        "$WORK/busybox-build.log" || true

    exit "$STATUS"
fi

echo "==> Installing BusyBox"

mkdir -p "$ROOTFS"

make -C "$WORK/busybox" CONFIG_PREFIX="$ROOTFS" install

echo "==> Preparing root filesystem"

mkdir -p "$ROOTFS"/{dev,proc,sys,etc,tmp,root}

sudo mknod -m 600 "$ROOTFS/dev/console" c 5 1
sudo mknod -m 666 "$ROOTFS/dev/null" c 1 3

cat > "$ROOTFS/init" <<'INIT'
#!/bin/sh

mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t proc proc /proc
mount -t sysfs sysfs /sys

echo
echo "================================"
echo "          GLITCH//CORE"
echo "================================"
echo
echo "Minimal Linux prototype"
echo
echo "Kernel started successfully."
echo "BusyBox shell is ready."
echo
echo "Type 'help' for commands."
echo

exec /bin/sh
INIT

chmod +x "$ROOTFS/init"

cat > "$ROOTFS/etc/issue" <<'ISSUE'
GLITCH//CORE - experimental prototype
ISSUE

echo "==> Creating initramfs"

(
    cd "$ROOTFS"
    find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9
) > "$WORK/initramfs.cpio.gz"

echo "==> Preparing GRUB"

mkdir -p "$WORK/iso/boot/grub"

cp "$WORK/linux/arch/x86/boot/bzImage" \
    "$WORK/iso/boot/vmlinuz"

cp "$WORK/initramfs.cpio.gz" \
    "$WORK/iso/boot/initramfs.cpio.gz"

cat > "$WORK/iso/boot/grub/grub.cfg" <<'GRUB'
set timeout=3
set default=0

menuentry "GLITCH//CORE" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.cpio.gz
}
GRUB

echo "==> Generating bootable ISO"

grub-mkrescue \
    -o "$DIST/GLITCH-CORE.iso" \
    "$WORK/iso"

echo
echo "================================"
echo " GLITCH//CORE BUILD COMPLETED"
echo "================================"

ls -lh "$DIST/GLITCH-CORE.iso"
