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
bash scripts/lfs/check-graphics-target.sh /absolute/path/to/target-rootfs
bash scripts/lfs/check-mate-target.sh /absolute/path/to/target-rootfs
bash scripts/lfs/install-mate-config.sh /absolute/path/to/target-rootfs
```

The installer refuses the host root filesystem and checks required desktop
components plus the Xorg/Mesa graphics files before changing the target. The
MATE target inspection also runs the graphics readiness gate.

## Package management: APT + dpkg target

The project targets native builds of **dpkg and APT** from upstream source,
compiled against the GLITCH//CORE LFS userspace. The intended package format
is .deb, with a GLITCH//CORE-owned signed repository and metadata.

This does **not** make GLITCH//CORE Debian-based. Debian/Ubuntu binary
packages and repositories must not be used as the system base or default
package source. See `config/package-manager.txt`.

APT is not installed in the LFS target or usable yet. CI now compiles dpkg/APT from the pinned source archives into isolated artifacts on an Ubuntu build runner; those artifacts are not target packages and must not be advertised as available
until dpkg, apt-get, apt-cache, signature verification, dependency resolution
and package install/upgrade/remove tests pass in the target system.

## LFS milestones

- `scripts/build-lfs.sh` — downloads and verifies the official LFS 13.1-systemd source set.
- `scripts/lfs/check-host.sh` — read-only build-host preflight.
- `scripts/lfs/check-desktop-build-host.sh` — read-only preflight for the graphical build host (Meson, Ninja, CMake, GTK/MATE build tooling and available resources). The manual `build.yml` workflow installs these host tools and runs the check; this still does not compile the desktop.
- `scripts/lfs/build-toolchain-pass1.sh` — experimental Binutils/GCC cross-toolchain Pass 1.
- `scripts/lfs/validate-mate-stack.sh` — validates the MATE target manifest.
- `config/graphics-stack.txt` — explicit Mesa, Xorg, protocol/library and input-stack inventory.
- `scripts/lfs/validate-graphics-stack.sh` and `test-graphics-stack.sh` — validate the graphics inventory and test missing/duplicate target rejection.
- `config/graphics-build-order.txt` — staged dependency order and release gates for reproducible Xorg/Mesa builds.
- `config/graphics-sources.lock` — initial partial source lock for Mesa 26.2.6, libdrm 2.4.134, Xorg server 21.1.25 and xorgproto 2026.1, with HTTPS URLs and SHA-256 values.
- `docs/GRAPHICS-SOURCE-PINS.md` — provenance for the pinned archive checksums and remaining source-lock work.
- `scripts/lfs/validate-graphics-sources.sh` and `test-graphics-sources.sh` — validate pinned source metadata and reject unsafe or incomplete entries.
- `scripts/lfs/fetch-graphics-sources.sh` — download locked archives over HTTPS and verify SHA-256; supports selecting one package so build jobs do not fetch the entire partial lock unnecessarily.
- `scripts/lfs/build-xorgproto.sh` — compile the pinned xorgproto 2026.1 source with Meson/Ninja into an isolated DESTDIR staging tree (not directly into the target rootfs).
- `scripts/lfs/test-xorgproto-build.sh` — checks the xorgproto build pipeline safeguards.
- `.github/workflows/build.yml` — includes a dedicated xorgproto build job on the desktop feature branch and uploads its staged output as an artifact.
- `.github/workflows/graphics-sources.yml` — manually triggered workflow that uploads the verified partial source set as a short-lived artifact.
- `scripts/lfs/check-graphics-target.sh` and `test-graphics-target.sh` — inspect staged Xorg/Mesa file types and exercise standard/alternate layouts, missing components and safety guards with fixtures.
- `scripts/lfs/test-mate-config.sh` — tests MATE session configuration and safety guards.
- `scripts/lfs/check-mate-target.sh` — read-only inspection of an installed MATE target. It also checks GTK 3 runtime libraries, compiled GLib schemas and the LightDM GTK greeter executable.
- `scripts/lfs/test-mate-target.sh` — fixture-based regression tests for complete/incomplete desktop targets, GTK runtime and greeter detection.
- `scripts/lfs/validate-package-manager.sh` — validates the APT/dpkg integration plan.
- `config/package-manager-sources.lock` — pinned dpkg 1.23.11 and APT 3.0.4 source archives with SHA-256 digests; these are source-only inputs, not Debian binary packages.\n- `scripts/lfs/validate-package-manager-sources.sh` and `fetch-package-manager-sources.sh` — validate and fetch the pinned native package-manager source archives.\n- `scripts/lfs/build-dpkg.sh` and `build-apt.sh` — native source-build recipes that stage outputs with DESTDIR, without installing into the host or target rootfs.\n- `scripts/lfs/test-package-manager-build.sh` — source-lock and build-recipe safety regression tests.\n- `scripts/lfs/build-libdrm.sh` — compiles the pinned libdrm prerequisite into an isolated staging tree.\n- `.github/workflows/build.yml` — compiles dpkg/APT and libdrm into separate short-lived CI artifacts for review; CI runner packages are build dependencies only.

The graphics source lock is intentionally **partial**: it pins four upstream archives only, not every dependency in the graphics inventory. xorgproto and libdrm now have individual source-build recipes and CI artifacts; Mesa and Xorg still require their full dependency closure and target integration. The remaining packages, signatures, patches, build options and target dependency closure still need review before a complete Xorg/Mesa build can be enabled.

The LFS source preparation and cross-toolchain Pass 1 are intermediate
milestones. They do not yet produce a complete LFS userspace.

## Build and CI

GitHub Actions validates shell syntax, the MATE configuration and the
package-manager plan on pushes and pull requests. The expensive rescue ISO
build runs manually or on pushes to `main`. The manual workflow also offers
LFS source preparation and the experimental toolchain Pass 1.

A successful CI staging build is **not** proof that MATE or APT has been installed in the LFS target. A successful validation job is **not** proof that the full desktop has been built.
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


## GLITCH application development (initial SDK)

The first host-side application SDK is available under `scripts/glitch-sdk/`.
It uses Python's standard library and defines an initial `.gcpkg` archive
format. The SDK currently validates source directories, creates application
archives and inspects archives without executing their contents.

Try the example app:

```bash
python3 scripts/glitch-sdk/glitch.py validate examples/apps/hello-world
python3 scripts/glitch-sdk/glitch.py pack examples/apps/hello-world --output /tmp/hello.gcpkg
python3 scripts/glitch-sdk/glitch.py inspect /tmp/hello.gcpkg
python3 examples/apps/hello-world/main.py
```

Run the SDK regression tests:

```bash
python3 scripts/glitch-sdk/test-sdk.py
```

Application metadata lives in `glitch-app.json`. See
`config/app-package-format.txt` for the v1 package contract.

**Current limitation:** this is developer tooling, not an OS package installer.
There is no system-wide installation, signature verification, dependency
resolver, sandbox or application store yet. Do not treat untrusted packages
as safe to execute. The SDK is not yet integrated into the rescue ISO.


### First graphical application: GLITCH//CORE Settings

The GTK 3 developer preview is in `examples/apps/settings/`. It includes
System, Appearance and About pages, with an in-window light/dark preview and
accent-color selector. The appearance controls affect only the preview and
are not persisted or applied to system settings.

It requires GTK 3 and PyGObject, which are not part of the current BusyBox
rescue ISO. The CI validation compiles its Python source, validates its app
manifest, packages it with the SDK and inspects the resulting archive.
