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

The logo, wallpaper and blue/purple/pink palette will be applied after the
graphical session is integrated and boots reliably.

## Package management

APT and dpkg are being built from source as native GLITCH//CORE components.
Successful host-side staging does not count as installation in the LFS target
rootfs. They must still be installed and tested inside the same target rootfs
as the desktop.

The intended package source is a signed GLITCH//CORE repository. Compatibility
with arbitrary Debian packages is not promised: dependencies, filesystem
layout and maintainer scripts must match GLITCH//CORE.

## Verified CI snapshot — 25 November 2026, 12:45 UTC

- **Chapter 8.3 — Man-pages 6.18:** successful run
  [45586451667](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45586451667).
  Installed inside the LFS chroot; artifact
  `glitch-core-lfs-chapter8-man-pages-x86_64` was published.
- **Chapter 8.4 — IANA-etc 20260805:** successful run
  [45596825403](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825403).
  The Chapter 8.4 checkpoint artifact
  `glitch-core-lfs-chapter8-iana-etc-x86_64` was published (about 5.05 GB).
- **Chapter 8.5 — Glibc 2.44:** builder, preflight regression test and workflow
  were added on `feature/mate-desktop`. Workflow
  [45616626689](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45616626689)
  has started; it restores the Chapter 8.4 checkpoint, validates source
  archives/patches and will run the critical Glibc test suite. No Glibc
  installation or Chapter 8.5 checkpoint is claimed until that run passes.
- **Chapter 8.6 — Zlib 1.3.2:** builder, regression tests and manual checkpoint workflow are prepared on `feature/mate-desktop`. It must wait for a successful Chapter 8.5 Glibc artifact; no Zlib target installation is claimed yet.
- **Chapter 8.7 — Bzip2 1.0.8:** LFS-recipe builder, source/patch checksum preflight, regression tests and a manual workflow consuming the Chapter 8.6 checkpoint have been added. The workflow has not been dispatched; no Bzip2 installation is claimed.
- **MATE configuration and integration checks:** passed, including
  [45616614484](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45616614484).
  These are configuration and script checks, not a running desktop.
- **Graphics foundation staging:** xorgproto, xtrans and libdrm compiled and
  were published in
  [45596825370](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825370).
  They remain host-side staging outputs, not installed in LFS.
- **APT/dpkg:** native source builds and artifact collection passed in
  [45596825370](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825370)
  and [45597267054](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45597267054).
  They are not yet installed in the LFS target rootfs.
- The Chapter 8 manifest validator checks package inventory/order only; it
  does not prove all 80 packages have been built.

## Milestones

1. Preserve the current BusyBox ISO as the rescue/bootstrap prototype.
2. Complete sequential LFS 13.1-systemd Chapter 8 package builds, restoring
   each verified checkpoint rather than rebuilding earlier stages.
3. Boot the completed LFS base in QEMU and validate kernel, systemd, storage,
   networking and essential services.
4. Build Xorg/Mesa/GTK dependencies against the LFS rootfs, then integrate
   MATE, Marco, Caja and LightDM.
5. Build and install dpkg and APT natively into that same LFS rootfs.
6. Create signed GLITCH//CORE repository metadata and test package
   installation, upgrade and removal.
7. Integrate the LFS rootfs and graphical session into a bootable ISO.
8. Test the ISO in QEMU and publish an experimental artifact with checksum
   and reproducible test instructions.

## Acceptance rule for the first graphical + APT test ISO

Do not announce a user-testable release until one downloadable ISO satisfies
all of these conditions:

- It boots the LFS-built system in QEMU, not only the BusyBox rescue image.
- A real MATE graphical session starts in the target rootfs.
- dpkg and APT are installed in that same target rootfs.
- APT refreshes the GLITCH//CORE repository index and installs a test package.
- The workflow publishes the ISO, SHA-256 checksum, run link and test steps.

Until then, report chapter checkpoints, host-side builds and configuration
validation as separate achievements. None is a complete graphical release.
