# GLITCH//CORE — LFS 13.1-systemd Chapter 8 plan

## Purpose

Chapter 8 is the transition from temporary chroot tools to the real GLITCH//CORE base userspace. It follows the official LFS 13.1-systemd package sequence. It is not the MATE desktop build and it does not make the distribution Debian-based.

## Entry gate

Do not start Chapter 8 builds until the Chapter 7 recovery workflow has uploaded and verified the artifact `glitch-core-lfs-toolchain-chapter7-x86_64`. The restored checkpoint must contain:

- `tools/.glitchcore-chapter7-temporary-tools-complete`
- `CHAPTER-7-BUILD-INFO.txt` with the eight temporary packages and source SHA-256 values
- a working native chroot with `bash`, `python3`, `bison`, `makeinfo`, and `mount`
- the LFS 13.1-systemd source manifests and checksum-verified archives

## Chapter 8 inventory

`config/lfs-chapter8-build-order.txt` records the official Chapter 8 package order and versions. The validator checks row format, contiguous ordering, duplicates, the LFS book version, and critical version pins. The inventory is sourced from the official LFS book:

https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter08/chapter08.html

## Build strategy

1. Restore the Chapter 7 tar checkpoint without losing ownership, permissions, symlinks, or hidden completion markers.
2. Verify the Chapter 7 completion marker and provenance before any writes.
3. Build Chapter 8 packages inside the target chroot in the order recorded in the manifest, using package-specific recipes from LFS 13.1-systemd.
4. Record one completion marker per package only after its install and required smoke checks succeed.
5. Keep logs, source checksums, build options, and package provenance in the checkpoint.
6. Run target-rootfs checks for dynamic loader, shared libraries, core utilities, shell, package tools, systemd, udev, and filesystem utilities.
7. Package the Chapter 8 checkpoint as a tar archive and verify the archive before upload.

## Boundaries

- The current rescue ISO remains a BusyBox prototype until a later rootfs/boot integration milestone.
- MATE, Xorg, Mesa, LightDM, and the graphical applications remain separate later stages.
- dpkg and APT are GLITCH//CORE's intended native package-management layer; CI-host binaries must never be copied into the target as if they were target-native builds.
- The official LFS book remains the build reference. No Debian/Ubuntu root filesystem or binary package base is introduced.

## Verified progress — 2026-11-28

The first three Chapter 8 package stages are implemented as separate, restartable workflows:

- Chapter 8.3: Man-pages 6.18
- Chapter 8.4: IANA-etc 20260805
- Chapter 8.5: Glibc 2.44

The latest Glibc workflow run (#8) completed successfully on 2026-11-27. Its run ID is `46009716834`, and the run uploaded the artifact `glitch-core-lfs-chapter8-glibc-x86_64`. The artifact was checked on 2026-11-28 and was present and not expired. This is a verified Chapter 8 checkpoint, not a complete LFS system or bootable desktop ISO.

## Next stage

Chapter 8.6 is Zlib 1.3.2. The builder, preflight regression test, and manual workflow are present:

- `scripts/lfs/build-chapter8-zlib.sh`
- `scripts/lfs/test-chapter8-zlib.sh`
- `.github/workflows/lfs-chapter8-zlib.yml`

To continue, manually dispatch the Zlib workflow and supply the successful Glibc source run ID `46009716834`. The workflow must restore and verify the Chapter 8.5 artifact before it starts the Zlib build. Do not start Chapter 8.7 Bzip2 until the Zlib workflow uploads its verified checkpoint.

