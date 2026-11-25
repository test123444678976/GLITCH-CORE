# GLITCH//CORE — LFS, MATE and APT roadmap

## Project direction

GLITCH//CORE is an independent x86_64 Linux distribution built from Linux
From Scratch (LFS) 13.1-systemd. Debian is not the base system. The BusyBox
ISO remains a separate rescue/bootstrap prototype while the LFS rootfs is
being built.

## Target desktop

- MATE as the primary desktop
- Marco, Caja and LightDM
- Xorg as the initial display server
- Mesa / DRM graphics stack
- NetworkManager and systemd

The project's logo, wallpaper and blue/purple/pink palette will be applied
once the graphical session is integrated and boots reliably.

## Package management

APT and dpkg are intended to be built from source for the LFS userspace.
They are not yet installed in the LFS rootfs. Host-side staging builds do
not count as target integration.

The target is a GLITCH//CORE package repository with signed metadata and
tested install/upgrade/remove operations. Compatibility with arbitrary
Debian packages is not promised: package dependencies, filesystem layout
and maintainer scripts must be compatible with GLITCH//CORE.

## Latest CI snapshot — 25 November 2026

- Chapter 8.3 Man-pages 6.18: successful workflow run
  [45586451667](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45586451667).
  It restored the verified Chapter 7 checkpoint, installed Man-pages in the
  LFS chroot and uploaded the Chapter 8.3 checkpoint artifact.
- Chapter 8.4 IANA-etc 20260805: workflow run
  [45595754732](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45595754732)
  is running. Its protocol-number-zero validation now expects the canonical
  `hopopt 0 HOPOPT` entry. Do not treat the checkpoint as complete until
  the workflow uploads its artifact and the run concludes successfully.
- MATE configuration validation: runs
  [45595743248](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45595743248),
  [45595735056](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45595735056)
  and [45595730383](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45595730383)
  passed. These are configuration/manifest checks, not a running desktop.
- Chapter 8 checkpoint archive validation was hardened to avoid a
  `tar | grep -q` SIGPIPE failure under `pipefail`.
- The package-manager source/build scripts exist, but dpkg and APT are still
  host-side staged outputs; they have not been installed or tested inside
  the LFS target rootfs.

## Milestones

1. Preserve the current BusyBox ISO as the rescue/bootstrap prototype.
2. Complete the sequential LFS 13.1-systemd Chapter 8 package builds,
   restoring each verified checkpoint rather than rebuilding earlier stages.
3. Boot the completed LFS base in QEMU and validate kernel, systemd, storage,
   networking and essential services.
4. Build the Xorg/Mesa/GTK dependencies against the LFS rootfs, then integrate
   MATE, Marco, Caja and LightDM.
5. Build and install dpkg and APT natively into that same LFS rootfs.
6. Create signed GLITCH//CORE repository metadata and test package
   installation, upgrade and removal.
7. Integrate the LFS rootfs and graphical session into a bootable ISO.
8. Test the ISO in QEMU and publish a clearly labelled experimental artifact
   with checksum and reproducible test instructions.

## Acceptance rule for the first graphical + APT test ISO

Do not announce a user-testable release until one downloadable ISO satisfies
all of these conditions:

- It boots the LFS-built system in QEMU (not only the BusyBox rescue image).
- A real MATE graphical session starts in the target rootfs.
- dpkg and APT are installed in that same target rootfs.
- APT can refresh the GLITCH//CORE repository index and install a test package.
- The workflow publishes the ISO, SHA-256 checksum, run link and test steps.

Until then, report Chapter checkpoints, host-side builds and configuration
validation as separate achievements; none is a complete graphical release.
