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

## Latest CI snapshot — 23 November 2026

- LFS workflow run [45016697312](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697312): official LFS sources, Chapter 5 cross-toolchain, Chapter 6 temporary tools/GCC Pass 2 and Chapter 7 chroot preparation all passed. The Chapter 7 build step itself completed all eight temporary packages inside chroot. Its next verification step failed because the workflow tried to execute the target Python binary directly from the host, where the target `libpython3.14.so.1.0` is not in the host library search path. Therefore no Chapter 7 final checkpoint artifact was uploaded.
- The main workflow verification was corrected to run Chapter 7 tools inside the LFS chroot. A separate manual recovery workflow, [lfs-chapter7-recovery.yml](https://github.com/test123444678976/GLITCH-CORE/blob/feature/mate-desktop/.github/workflows/lfs-chapter7-recovery.yml), was added to reuse the successful Chapter 6 checkpoint from run 45016697312 and rebuild/verify Chapter 7 without repeating Chapters 5 and 6. The recovery workflow still needs to be run.
- Main workflow run [45016697296](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697296): project validation passed; graphical component builds and collection were running earlier. This separate feature-branch workflow skips rescue ISO/LFS jobs.
- Chapter 5, Chapter 6 and Chapter 7 chroot-bootstrap archives are CI checkpoints, not a bootable installation.
- MATE validation run [44712727759](https://github.com/test123444678976/GLITCH-CORE/actions/runs/44712727759): configuration checks passed; this is not a graphical desktop build.

## Build milestones

1. Keep the current BusyBox ISO as the known-good bootstrap/rescue prototype.
2. Continue the LFS 13.1 systemd build. The official source set and Chapters
   5 and 6 are verified in CI checkpoints. The Chapter 7 build step completed
   all eight temporary packages inside chroot, but its post-build verification
   initially ran Python outside the target rootfs and failed; no final Chapter
   7 checkpoint was uploaded. The verifier is fixed and a recovery workflow
   reuses the Chapter 6 artifact. Run that recovery workflow and confirm its
   Chapter 7 artifact before starting Chapter 8. Chapters 8+ are not built.
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
- LFS Chapter 7 temporary tools: `scripts/lfs/build-toolchain-chapter7.sh` completed all eight pinned package recipes inside chroot in run [45016697312](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697312), and the builder's internal checks passed. The separate host-side verification failed because it launched target Python outside chroot, so no final Chapter 7 artifact was uploaded. The verifier now runs tools inside chroot. The new `.github/workflows/lfs-chapter7-recovery.yml` resumes from the successful Chapter 6 checkpoint; its manual run and final artifact verification are pending.
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
