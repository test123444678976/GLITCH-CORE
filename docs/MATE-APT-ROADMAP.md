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
The successful host-side staging jobs do not count as installation in the
LFS target rootfs. They must still be built/installed and tested inside the
same target rootfs as the desktop.

The intended package source is a signed GLITCH//CORE repository. Compatibility
with arbitrary Debian packages is not promised: dependencies, filesystem
layout and maintainer scripts must match GLITCH//CORE.

## Verified CI snapshot — 25 November 2026, 10:39 UTC

- **Chapter 8.3 — Man-pages 6.18:** successful run
  [45586451667](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45586451667).
  It installed Man-pages inside the LFS chroot and uploaded
  `glitch-core-lfs-chapter8-man-pages-x86_64` (about 5.05 GB).
- **Chapter 8.4 — IANA-etc 20260805:** retry
  [45596825403](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825403)
  is still in progress. The Chapter 8.3 artifact download completed; restore
  and verification of that checkpoint is currently running. IANA-etc has not
  yet been confirmed installed and its checkpoint artifact does not yet exist.
  The preceding failure [45595754732](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45595754732)
  was traced to an overly strict services-record validation expression.
  The installer and regression test were corrected in commits
  `e6a4d236` and `b2e44088`; the retry must pass before Chapter 8.4 is closed.
- **MATE configuration and integration-plan checks:** passed in
  [45596825370](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825370)
  and [45596812757](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596812757).
  These validate configuration/manifests; they do not prove a running desktop.
- **Graphics foundation staging:** xorgproto, xtrans and libdrm compiled and
  uploaded successfully in [45596825370](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596825370).
  These are build-host staging artifacts, not yet installed in LFS.
- **APT/dpkg:** dpkg compilation completed in the latest host job and APT
  compilation was still running at the last check. Earlier successful
  host-side staging is recorded in
  [45596151272](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45596151272).
  Neither package manager is yet installed in the LFS target rootfs.
- The Chapter 8 package manifest validator checks the 80-row inventory and
  ordering only; it is not evidence that all 80 packages have been built.

## Milestones

1. Preserve the current BusyBox ISO as the rescue/bootstrap prototype.
2. Complete the sequential LFS 13.1-systemd Chapter 8 package builds,
   restoring each verified checkpoint rather than rebuilding earlier stages.
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
