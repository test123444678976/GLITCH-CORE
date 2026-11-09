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

APT is still a requested project feature. It must not be represented as
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

## Build milestones

1. Keep the current BusyBox ISO as the known-good bootstrap/rescue prototype.
2. Complete the LFS 13.1 systemd build. The current
   scripts/build-lfs.sh only downloads and verifies source archives; it does
   not compile LFS yet.
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

- Kernel + static BusyBox bootable prototype: present in scripts/build.sh.
- LFS 13.1 source download and MD5 verification: present in
  scripts/build-lfs.sh.
- Full LFS compilation: not implemented yet.
- MATE stack target manifest: present in `config/mate-stack.txt` (planning/integration input only).
- MATE desktop binaries, Xorg session and graphical login: not built or installed yet.
- APT/dpkg integration: not implemented yet.
- LFS desktop ISO: not implemented yet.

Do not describe source preparation as a completed LFS build, and do not
describe APT or MATE as available until the corresponding milestones pass
tests.


## Build environment

The first implementation step is a read-only host preflight at
`scripts/lfs/check-host.sh`. See
`docs/LFS-BUILD-ENVIRONMENT.md` for requirements and staged implementation.
The source downloader remains a preparation step only.
