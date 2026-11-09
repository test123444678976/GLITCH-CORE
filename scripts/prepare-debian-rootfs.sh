#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$ROOT/work}"
ROOTFS="${ROOTFS:-$WORK/debian-rootfs}"
PACKAGES_FILE="$ROOT/config/desktop-packages.txt"
SUITE="${DEBIAN_SUITE:-trixie}"
MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this script with sudo." >&2
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "ERROR: debootstrap is required on the build host." >&2
    echo "Install it with: sudo apt-get install debootstrap" >&2
    exit 1
fi

if [[ ! -f "$PACKAGES_FILE" ]]; then
    echo "ERROR: package list not found: $PACKAGES_FILE" >&2
    exit 1
fi

mapfile -t PACKAGES < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$PACKAGES_FILE")
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "ERROR: package list is empty." >&2
    exit 1
fi

mkdir -p "$WORK"
if [[ -e "$ROOTFS" ]]; then
    echo "ERROR: refusing to overwrite existing rootfs: $ROOTFS" >&2
    echo "Move it away or set ROOTFS to a new path." >&2
    exit 1
fi

echo "==> Preparing Debian ${SUITE} root filesystem"
echo "==> Installing APT, dpkg, systemd, Xorg, LightDM and MATE"

debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --include="$(IFS=,; echo "${PACKAGES[*]}")" \
    "$SUITE" "$ROOTFS" "$MIRROR"

install -D -m 0644 /dev/null "$ROOTFS/etc/hostname"
printf '%s\n' 'glitch-core' > "$ROOTFS/etc/hostname"

install -D -m 0644 /dev/null "$ROOTFS/etc/hosts"
cat > "$ROOTFS/etc/hosts" <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 glitch-core
::1       localhost ip6-localhost ip6-loopback
HOSTS

install -D -m 0644 /dev/null "$ROOTFS/etc/issue"
printf '%s\n' 'GLITCH//CORE - MATE desktop prototype' > "$ROOTFS/etc/issue"

mkdir -p "$ROOTFS/etc/apt/apt.conf.d"
cat > "$ROOTFS/etc/apt/apt.conf.d/99glitchcore" <<'APTCONF'
Acquire::Retries "3";
APTCONF

echo "==> Configuring graphical boot target"
chroot "$ROOTFS" systemctl set-default graphical.target
chroot "$ROOTFS" systemctl enable NetworkManager.service
chroot "$ROOTFS" systemctl enable lightdm.service

echo
echo "Debian root filesystem prepared at: $ROOTFS"
echo "APT and dpkg are installed inside this rootfs."
echo "This is a preparation stage; it is not yet wired into the bootable ISO."
