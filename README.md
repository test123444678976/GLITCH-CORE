# GLITCH//CORE

Experimental independent x86_64 Linux distribution project.

## Current status (November 2026)

GLITCH//CORE is being developed as an independent Linux From Scratch (LFS)
13.1-systemd-based distribution. Debian is **not** the operating-system base.

The current bootable ISO is still a BusyBox rescue prototype. It is useful
for checking the kernel, GRUB and initramfs, but it is **not** the finished
desktop operating system.

## Desktop target: MATE

The primary desktop target is **MATE**, replacing the earlier GNOME plan.
The intended stack includes:

- Xorg and Mesa graphics
- GTK 3, GLib, Cairo and Pango
- MATE session, panel, settings daemon and control center
- Marco window manager and Caja file manager
- LightDM with the GTK greeter
- D-Bus, systemd-logind, Polkit and NetworkManager
- GVFS, UDisks2, UPower, AccountsService and keyring/secret integration
- libinput and Xorg input support, with optional hardware-specific video drivers

The MATE and dedicated Xorg/Mesa graphics manifests, LightDM session files and guarded target-rootfs
configuration scripts are in this branch. The target installer enables
D-Bus and LightDM, and enables NetworkManager when its unit is present. They are configuration and
validation work only: **MATE has not yet been compiled into the target rootfs
or included in a bootable desktop ISO**.

After the complete desktop packages have been built and installed into a
target rootfs, inspect it with:

```bash
bash scripts/lfs/check-mate-target.sh /absolute/path/to/target-rootfs
bash scripts/lfs/install-mate-config.sh /absolute/path/to/target-rootfs
```

The installer refuses the host root filesystem and checks required desktop
components before changing the target.

## Package management: APT + dpkg target

The project targets native builds of **dpkg and APT** from upstream source,
compiled against the GLITCH//CORE LFS userspace. The intended package format
is .deb, with a GLITCH//CORE-owned signed repository and metadata.

This does **not** make GLITCH//CORE Debian-based. Debian/Ubuntu binary
packages and repositories must not be used as the system base or default
package source. See `config/package-manager.txt`.

APT is not installed or usable yet. It must not be advertised as available
until dpkg, apt-get, apt-cache, signature verification, dependency resolution
and package install/upgrade/remove tests pass in the target system.

## LFS milestones

- `scripts/build-lfs.sh` — downloads and verifies the official LFS 13.1-systemd source set.
- `scripts/lfs/check-host.sh` — read-only build-host preflight.
- `scripts/lfs/build-toolchain-pass1.sh` — experimental Binutils/GCC cross-toolchain Pass 1.
- `scripts/lfs/validate-mate-stack.sh` — validates the MATE target manifest.
- `config/graphics-stack.txt` — explicit Mesa, Xorg, protocol/library and input-stack inventory.
- `scripts/lfs/validate-graphics-stack.sh` and `test-graphics-stack.sh` — validate the graphics inventory and test missing/duplicate target rejection.
- `scripts/lfs/test-mate-config.sh` — tests MATE session configuration and safety guards.
- `scripts/lfs/check-mate-target.sh` — read-only inspection of an installed MATE target.
- `scripts/lfs/validate-package-manager.sh` — validates the APT/dpkg integration plan.
- `scripts/lfs/test-package-manager.sh` — positive/negative tests for the package plan and repository safety policy.

The LFS source preparation and cross-toolchain Pass 1 are intermediate
milestones. They do not yet produce a complete LFS userspace.

## Build and CI

GitHub Actions validates shell syntax, the MATE configuration and the
package-manager plan on pushes and pull requests. The expensive rescue ISO
build runs manually or on pushes to `main`. The manual workflow also offers
LFS source preparation and the experimental toolchain Pass 1.

A successful validation job is **not** proof that MATE or APT has been built.
A successful rescue ISO job is **not** a desktop ISO.

## Test the current rescue ISO with QEMU

If QEMU is installed:

```bat
qemu-system-x86_64.exe -m 1024 -cdrom GLITCH-CORE.iso -boot d
```

## Architecture

- Target architecture: x86_64
- Intended base: LFS 13.1-systemd
- Desktop: MATE
- Display server: Xorg
- Login manager: LightDM
- Package management target: dpkg + APT, using GLITCH//CORE repositories
- Current bootable milestone: Linux kernel + static BusyBox + initramfs + GRUB

The GitHub-hosted Ubuntu runner is only a temporary build machine. It does
not install Ubuntu or Debian into GLITCH//CORE and does not install Linux on
your Windows computer.
