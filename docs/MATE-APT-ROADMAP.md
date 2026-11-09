# GLITCH//CORE — Debian, APT and MATE integration

## Target

The desktop edition will use a Debian Trixie amd64 userspace. The existing
GLITCH//CORE Linux kernel and GRUB boot flow remain project-controlled.
APT and dpkg are first-class components of the installed system.

## Desktop stack

- APT and dpkg — package management
- systemd — init and service management
- Xorg — display server
- LightDM — graphical login manager
- MATE — primary desktop environment
- Caja — file manager
- Marco — window manager
- NetworkManager — network management

The package selection is maintained in `config/desktop-packages.txt`.

## Build stages

1. Keep the existing BusyBox prototype unchanged on `main`.
2. Prepare a Debian Trixie amd64 root filesystem with debootstrap.
3. Install and configure APT, systemd, Xorg, LightDM and MATE in that rootfs.
4. Add a live-root boot design (compressed SquashFS plus a small initramfs).
5. Integrate the live root into the GRUB ISO and test booting in QEMU.
6. Apply the existing GLITCH//CORE logo, wallpaper and color palette.
7. Add a persistent-install option only after the live desktop is stable.

## Important implementation note

`scripts/prepare-debian-rootfs.sh` prepares the Debian userspace. It does
not yet replace `scripts/build.sh` or create a desktop ISO. The current
BusyBox ISO remains the known-good prototype until the Debian live-root boot
path has been implemented and tested.

## Build host requirements

The preparation script expects a Debian/Ubuntu build host with `debootstrap`
installed and must be run as root (for example, with `sudo`). The GitHub
Actions runner can install `debootstrap` in a later workflow step.
