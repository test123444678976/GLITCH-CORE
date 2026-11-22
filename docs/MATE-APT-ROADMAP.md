# GLITCH//CORE — LFS, MATE and APT roadmap

## Project direction

GLITCH//CORE is an independent x86_64 Linux distribution built from Linux
From Scratch (LFS), using the systemd edition as its starting point.

**Debian is not the base system.** The Debian-based prototype files have been
removed from this branch. The existing BusyBox ISO remains a separate,
minimal rescue/bootstrap prototype until the LFS system can boot reliably.

## Target desktop

- MATE — primary desktop environment
- Marco — window manager
- Caja — file manager
- LightDM — graphical login manager
- Xorg — initial display server
- NetworkManager — network management
- systemd — init and service management

The project's own branding, wallpaper and GLITCH//CORE color palette will
be applied after the desktop boots reliably.

## Package management: APT is a goal, not yet implemented

APT is a project feature under development. It must not be represented as
working until it has been built, integrated and tested on the LFS system.

APT normally works with dpkg, .deb packages, package indexes, dependency
metadata, maintainer scripts and repository signing. Building APT and dpkg
for an LFS base does not automatically make arbitrary Debian packages
compatible: their dependencies, filesystem assumptions and maintainer
scripts must also match GLITCH//CORE.

The intended investigation is to build and integrate dpkg and APT from
source against the GLITCH//CORE userspace, then create a signed
GLITCH//CORE package repository. Compatibility with selected Debian
packages can be evaluated separately; it must never be promised globally.

## Latest CI snapshot — 22 November 2026

- Previous LFS workflow run [44712727722](https://github.com/test123444678976/GLITCH-CORE/actions/runs/44712727722): official source verification, Chapter 5, Chapter 6 and Chapter 7 chroot bootstrap passed. Its Chapter 7 checkpoint explicitly records `CHAPTER7_TEMPORARY_PACKAGES=not-built`.
- New LFS workflow run [45016697312](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697312): the Chapter 7 builder and its CI job have been added; the run is currently in progress, beginning with official source verification. No Chapter 7 package build is claimed yet.
- Main workflow run [45016697296](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697296): project validation passed; graphical component builds and collection are still running. The rescue ISO and LFS jobs in this separate workflow are skipped on feature-branch pushes.
- Chapter 5, Chapter 6 and Chapter 7 bootstrap archives are CI checkpoints, not a bootable installation.
- Main workflow run [44724561183](https://github.com/test123444678976/GLITCH-CORE/actions/runs/44724561183): validation completed successfully. Its feature-branch configuration skips the expensive rescue ISO build, so this run did not produce a new ISO.
- MATE validation run [44712727759](https://github.com/test123444678976/GLITCH-CORE/actions/runs/44712727759): configuration checks passed; this is not a graphical desktop build.

## Build milestones

1. Keep the current BusyBox ISO as the known-good bootstrap/rescue prototype.
2. Continue the LFS 13.1 systemd build. The official source set and Chapters
   5 and 6 are verified in CI checkpoints; Chapter 7 rootfs preparation and
   a native chroot smoke test now pass. The eight-package Chapter 7 builder
   and its workflow job are implemented, but the package build is pending CI
   verification. Chapters 8+ are not yet built.
3. Boot the LFS-built base system in QEMU and verify kernel, init, storage,
   networking and system services.
4. Resolve and build the dependencies required by `config/mate-stack.txt` against the completed LFS base; then build and integrate MATE, Marco, Caja, Xorg and LightDM. The manifest is a target list, not a package manager or build script.
5. Investigate and build dpkg and APT natively for the LFS userspace.
6. Create GLITCH//CORE package metadata, repository signing and package
   build rules; test install, upgrade and removal operations.
7. Integrate the LFS root filesystem and desktop into a bootable ISO.
8. Apply GLITCH//CORE branding and test the ISO in QEMU before considering
   installation to physical hardware.

## Current implementation status

- Kernel + static BusyBox bootable prototype: present in scripts/build.sh; it remains the separate rescue path.
- LFS 13.1-systemd source download and official MD5 verification: completed successfully in CI.
- LFS Chapter 5 cross-toolchain: Binutils Pass 1, GCC Pass 1, Linux API headers, Glibc and target Libstdc++ built and verified in CI run [43709102523](https://github.com/test123444678976/GLITCH-CORE/actions/runs/43709102523). The uploaded checkpoint is a CI artifact, not a bootable system.
- LFS Chapter 6 temporary tools: M4, Ncurses, Bash, Coreutils, Diffutils, File, Findutils, Gawk, Grep, Gzip, Make, Patch, Sed, Tar, Xz, Binutils Pass 2 and GCC Pass 2 built and verified in the same CI run. Its checkpoint is also a CI artifact.
- LFS Chapter 7 chroot bootstrap: rootfs layout, essential account files, virtual-kernel mounts and a native chroot smoke test passed in CI run [44712727722](https://github.com/test123444678976/GLITCH-CORE/actions/runs/44712727722).
- LFS Chapter 7 temporary tools: `scripts/lfs/build-toolchain-chapter7.sh` now implements the eight pinned LFS recipes inside chroot. `scripts/lfs/test-toolchain-chapter7.sh` tests its preflight and source guards. The workflow in `.github/workflows/lfs-toolchain.yml` now includes the Chapter 7 build and checkpoint upload. The first integrated run [45016697312](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697312) is in progress; until it succeeds, the eight packages are not claimed as built.
- Chapter 7 implementation specification: `docs/LFS-CHAPTER7-IMPLEMENTATION.md` records the pinned packages, official LFS recipes, safeguards and CI acceptance criteria.
- Full LFS userspace and bootable LFS ISO: not complete.
- MATE stack target manifest: present in config/mate-stack.txt (planning/integration input only).
- MATE manifest validator: present in scripts/lfs/validate-mate-stack.sh and wired into GitHub Actions.
- MATE desktop binaries, Xorg session and graphical login: not built or installed in the target rootfs.
- dpkg and APT: pinned upstream sources are compiled and smoke-tested on the Ubuntu CI host into isolated staging artifacts. They are not installed in the LFS rootfs; target-native integration, repository signing, dependency resolution and install/upgrade/remove tests remain outstanding.
- LFS desktop ISO: not implemented.

Do not describe CI checkpoints as a completed LFS installation, and do not
describe APT or MATE as available until their target integration and runtime
tests pass.

## Build environment

The read-only host preflight is at `scripts/lfs/check-host.sh`. See
`docs/LFS-BUILD-ENVIRONMENT.md` for requirements. The source downloader,
Chapter 5/6 checkpoint builds, Chapter 7 chroot bootstrap and Chapter 7
temporary-tools build are separate CI stages; none alone represents a
complete bootable LFS system.
