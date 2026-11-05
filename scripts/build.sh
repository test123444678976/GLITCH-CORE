#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
DIST="$ROOT/dist"

KERNEL_VERSION="6.12.58"
BUSYBOX_VERSION="1.36.1"

mkdir -p "$WORK" "$DIST"
rm -rf "$WORK/linux" "$WORK/busybox" "$WORK/rootfs" "$WORK/iso"
mkdir -f "$DIST" 2>/dev/null || true

echo "==> Downloading Linux ${KERNEL_VERSION}"
wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" -O "$WORK/linux.tar.xz"
tar -xf "$WORK/linux.tar.xz" -C "$WORK"
mv "$WORK/linux-${KERNEL_VERSION}" "$WORK/linux"

echo "==> Building Linux kernel"
make -C "$WORK/linux" defconfig
make -C "$WORK/linux" -j"$(nproc)" bzImage

echo "==> Downloading BusyBox ${BUSYBOX_VERSION}"
wget -q "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" -O "$WORK/busybox.tar.bz2"
tar -xf "$WORK/busybox.tar.bz2" -C "$WORK"
mv "$WORK/busybox-${BUSYBOX_VERSION}" "$WORK/busybox"

echo "==> Building static BusyBox"
make -C "$WORK/busybox" defconfig
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$WORK/busybox/.config"
make -C "$WORK/busybox" olddefconfig
make -C "$WORK/busybox" -j"$(nproc)"
make -C "$WORK/busybox" CONFIG_PREFIX="$WORK/rootfs" install

echo "==> Creating initramfs"
mkdir -p "$WORK/rootfs"/{dev,proc,sys,etc,tmp,root}
cat > "$WORK/rootfs/init" <<'INIT'
#!/bin/sh
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t proc proc /proc
mount -t sysfs sysfs /sys

clear
echo
echo "  GLITCH//CORE"
echo "  Minimal bootable Linux prototype"
echo
echo "  Kernel started successfully."
echo "  Type 'help' for available commands."
echo

exec /bin/sh
INIT
chmod +x "$WORK/rootfs/init"

cat > "$WORK/rootfs/etc/issue" <<'ISSUE'
GLITCH//CORE - experimental prototype
ISSUE

(
  cd "$WORK/rootfs"
  find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9
) > "$WORK/initramfs.cpio.gz"

echo "==> Creating bootable ISO"
mkdir -p "$WORK/iso/boot/grub"
cp "$WORK/linux/arch/x86/boot/bzImage" "$WORK/iso/boot/vmlinuz"
cp "$WORK/initramfs.cpio.gz" "$WORK/iso/boot/initramfs.cpio.gz"

cat > "$WORK/iso/boot/grub/grub.cfg" <<'GRUB'
set timeout=3
set default=0

menuentry "GLITCH//CORE" {
    linux /boot/vmlinuz quiet
    initrd /boot/initramfs.cpio.gz
}
GRUB

grub-mkrescue -o "$DIST/GLITCH-CORE.iso" "$WORK/iso"

echo "==> Build completed"
ls -lh "$DIST/GLITCH-CORE.iso"
