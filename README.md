# GLITCH//CORE

Experimental x86_64 Linux distribution project.

## Current prototype

The existing ISO build is a **bootable BusyBox rescue prototype**, not yet a
complete Linux From Scratch (LFS) operating system. It downloads and compiles
an upstream Linux kernel and static BusyBox, creates a small initramfs, and
packages them with GRUB.

The rescue ISO is intentionally kept separate while the LFS userspace is
developed. A successful rescue ISO build does not mean that the MATE desktop
is present.

## MATE desktop target

The intended primary desktop is **MATE**, replacing the earlier GNOME plan.
The integration target includes:

- MATE session, panel, settings daemon and control center
- Marco window manager and Caja file manager
- Xorg display server and Mesa graphics
- LightDM with the GTK greeter
- NetworkManager and systemd integration

The current MATE work lives on the `feature/mate-desktop` branch. The package
list in `config/mate-stack.txt` and build sequence in
`config/mate-build-order.txt` are planning/validation files. They do **not**
mean those packages have already been compiled or installed.

The LightDM session configuration is in `config/lightdm/` and
`config/xsessions/`. After all required packages have been built and installed
into a completed target root filesystem, the guarded integration script can
apply the session configuration:

```bash
bash scripts/lfs/install-mate-config.sh /absolute/path/to/target-rootfs
```

The script refuses to target `/` and checks for the required desktop,
display-server and LightDM files before changing the target.

## LFS preparation

The LFS 13.1-systemd source preparation and cross-toolchain Pass 1 are
experimental milestones. They do not yet produce a complete LFS userspace.
See:

- `scripts/build-lfs.sh` — downloads and verifies the LFS source set
- `scripts/lfs/check-host.sh` — read-only host preflight
- `scripts/lfs/build-toolchain-pass1.sh` — Binutils/GCC cross-toolchain Pass 1
- `scripts/lfs/validate-mate-stack.sh` — validates the MATE target manifest
- `scripts/lfs/test-mate-config.sh` — checks MATE integration configuration\n- `scripts/lfs/check-mate-target.sh` — read-only check of an installed MATE rootfs before integration

## Build the rescue ISO

The existing GitHub Actions workflow builds the BusyBox rescue ISO. It does
not yet build the LFS system or MATE desktop. Run it from the repository's
Actions tab and download the `glitch-core-iso` artifact after a successful run.

## Test with QEMU on Windows

If QEMU is already available, open Command Prompt in the folder containing
the ISO and run:

```bat
qemu-system-x86_64.exe -m 1024 -cdrom GLITCH-CORE.iso -boot d
```

## Project layout

- `.github/workflows/build.yml` — cloud build and validation workflow
- `scripts/build.sh` — builds kernel, BusyBox, initramfs and rescue ISO
- `scripts/build-lfs.sh` — prepares verified LFS sources
- `scripts/lfs/` — LFS and MATE build/integration scripts
- `config/` — kernel, MATE and desktop configuration
- `dist/` — generated ISO output (not committed)

## Important limitations

- Current ISO target: x86_64.
- The LFS work is incomplete; no complete LFS root filesystem is produced yet.
- MATE packages are not yet compiled into the ISO.
- APT is not yet implemented. Debian's APT cannot simply be copied into an
  arbitrary LFS system; package management needs a compatible package format,
  dependency database, repository metadata and package build pipeline.
- The GitHub-hosted runner is a temporary build environment and does not
  install Linux on your Windows computer.
