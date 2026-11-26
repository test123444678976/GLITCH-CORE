# GLITCH//CORE — LFS package-manager dependency audit

Status: engineering audit / planning document. This file does not claim that dpkg or APT has been built inside the target LFS rootfs.

Target: x86_64, LFS 13.1-systemd, branch `feature/mate-desktop`.

## Why the current CI artifacts are not enough

The current `scripts/lfs/build-dpkg.sh` and `scripts/lfs/build-apt.sh` compile with the Ubuntu CI host toolchain and install into isolated `DESTDIR` staging directories. Their provenance correctly records `install_mode=DESTDIR`. The staging audit explicitly does not prove compatibility with the LFS rootfs.

These scripts are useful host-side source/build checks, but they must not be used as the target installation path. A target builder must compile against libraries and headers inside the LFS system and install from inside a controlled chroot.

## Upstream dependency inventory

The lists below are derived from the upstream source package metadata for the exact pinned versions. Debian's build-dependency metadata is a reference inventory, not an instruction to use Debian binary packages or Debian as the GLITCH//CORE base. Some dependencies are conditional, test-only, documentation-only, or optional features; the target build must verify the actual upstream configure/CMake checks before selecting feature flags.

### dpkg 1.23.11

Upstream source metadata lists these principal build dependencies:

- pkgconf
- gettext (needed for NLS support)
- po4a (documentation/translation tooling)
- libmd
- zlib
- bzip2
- liblzma / Xz
- libzstd
- libselinux (platform-conditional)
- ncurses (used when building dselect)
- bzip2, xz-utils and zstd command-line tools for functional tests

The current Chapter 8 manifest already pins zlib 1.3.2, bzip2 1.0.8, Xz 5.8.3, Zstd 1.5.7, ncurses 6.6, gettext 1.0 and pkgconf 3.0.5. This is not proof that all corresponding target builders have completed successfully.

Important source-level details:
- dpkg probes libmd and its MD5 API; this must be resolved rather than silently ignored.
- SELinux and dselect are separately detected features. If GLITCH//CORE chooses to disable either, the exact supported configure option must be verified against the pinned 1.23.11 source before it is added to a build script.
- Keep the functional test suite enabled where its prerequisites are available; do not treat a successful compile alone as validation.

### APT 3.0.4

The upstream source package metadata lists these principal build dependencies:

- CMake and Ninja
- gettext and pkg-config
- zlib, bzip2, Xz/LZMA, LZ4 and Zstandard
- Berkeley DB development files
- OpenSSL
- libseccomp (architecture-conditional in upstream metadata)
- systemd and udev development interfaces on Linux
- xxHash
- triehash
- sqv or gpgv for OpenPGP signature verification
- documentation/test tooling when those build profiles are enabled

The current Chapter 8 manifest pins several of the compression libraries, OpenSSL, gettext, Ninja, pkgconf, systemd and D-Bus. However, the manifest does not currently list explicit pins for libmd, Berkeley DB, libseccomp, xxHash, triehash or an OpenPGP verifier. These are dependency gaps to resolve, not permission to copy host libraries into the target.

APT's upstream source also has integration tests. The build plan should distinguish:
1. configure/build and unit tests;
2. installation and dynamic-link validation inside LFS;
3. isolated integration tests using a disposable package database and local test repository;
4. repository signature verification and package install/upgrade/remove tests.

## Required implementation sequence

1. Inspect the exact pinned source archives and record the configure/CMake feature checks for dpkg 1.23.11 and APT 3.0.4.
2. Compare each required library/tool against the LFS Chapter 8 manifest and actual build scripts/checkpoint markers. A manifest entry alone is not a completed package.
3. Add missing LFS-native dependency builders and source locks where needed. Keep versions pinned and verify archive checksums.
4. Implement a dpkg target builder that checks prerequisites, mounts only the required virtual filesystems, builds in the LFS chroot, runs tests, installs into the LFS root, validates executables/libraries, and writes a completion marker only after success.
5. Implement APT after its complete dependency set is present. Verify that HTTPS and OpenPGP verification are enabled for the intended repository transport/security model.
6. Test package lifecycle using a disposable local GLITCH//CORE repository and a harmless test package. Do not enable a public repository until signed Release metadata and trust-key handling are implemented and tested.
7. Make architecture an explicit input to configuration and package metadata. The future ARM64/LXQt Raspberry Pi edition must have its own native ARM64 package-manager build; do not reuse x86_64 binaries.

## Acceptance criteria

- No executable or shared library is copied from Ubuntu into the LFS target.
- The build records source version, source SHA-256, target architecture, configure/CMake options, test results and installation manifest.
- dpkg and APT executables run inside the target chroot and resolve libraries only from the target root.
- A local signed repository can be indexed and verified.
- A disposable package can be installed, queried, upgraded and removed with the target dpkg/APT.
- Negative tests prove that missing prerequisites, invalid checksums, wrong architecture, host-root paths and failed tests prevent installation and completion markers.

## References

- dpkg 1.23.11 source package metadata: https://fossies.org/linux/dpkg/debian/control
- dpkg 1.23.11 configure feature detection: https://sources.debian.org/src/dpkg/1.23.12/configure.ac/
- APT 3.0.4 source package metadata: https://sources.debian.org/src/apt/3.0.4/debian/control
- APT upstream README and integration-test guidance: https://sources.debian.org/src/apt/3.0.4/README.md

The dpkg configure reference currently available upstream is 1.23.12; any configure option taken from it must be checked against the exact pinned 1.23.11 archive before implementation.
