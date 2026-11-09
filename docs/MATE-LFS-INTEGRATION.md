# MATE desktop integration on GLITCH//CORE

## Target

MATE is the planned primary desktop for GLITCH//CORE. The target component
list lives in `config/mate-stack.txt`. It is an integration manifest, not
an APT package list and not a build script.

The initial graphical stack is Xorg + LightDM + MATE, with Marco as the
window manager and Caja as the file manager. NetworkManager supplies network
management. This keeps the first graphical milestone on X11 while upstream
Wayland support and the required compositor/session pieces are evaluated
separately.

## Build gate

Do not start compiling MATE until all of these are true:

1. The LFS 13.1-systemd base has completed and boots in a VM.
2. The final LFS toolchain and development headers are available inside the
   target root filesystem.
3. D-Bus, GLib, GTK 3, Cairo, Pango, GObject Introspection, dconf,
   gsettings-desktop-schemas, polkit and the Xorg libraries are built and
   tested in GLITCH//CORE.
4. A reproducible package build/install mechanism exists for this LFS root.

The current successful Binutils/GCC Pass 1 checkpoint is only the beginning
of the LFS cross-toolchain; it is not sufficient to build desktop software.

## Integration order

Build and test in dependency layers, recording exact upstream release tags
and checksums before each source download:

1. **Graphics foundation:** Xorg server and required client libraries,
   Mesa, fonts, input drivers and a working Xorg test session.
2. **Desktop infrastructure:** D-Bus, polkit, dconf, GSettings schemas,
   startup-notification and the libraries required by MATE modules.
3. **MATE core:** mate-common, mate-desktop, mate-menus,
   mate-settings-daemon and mate-session-manager.
4. **Session shell:** Marco, mate-panel and Caja.
5. **Control and utilities:** mate-control-center, mate-notification-daemon,
   mate-polkit, mate-terminal, mate-system-monitor, mate-screenshot,
   mate-calc, Atril, Engrampa, Eye of MATE and Pluma.
6. **Login and networking:** LightDM with a GTK greeter and NetworkManager.
7. **System integration:** enable the display-manager service, provide a
   MATE session entry, set up D-Bus and polkit activation, and verify
   suspend/reboot, audio, removable media, user switching and networking.

The order is a project plan. Exact dependency edges must be resolved against
the selected upstream release tarballs and build-system checks before a
package recipe is marked complete.

## Version policy

Use the stable MATE 1.28 release line for the first integration baseline.
Do not mix development 1.29 snapshots into the initial desktop. Pin every
component to an exact upstream release tag and record its source URL and
SHA-256 checksum in the package recipe before building it. Update related
MATE modules together when their declared minimum-version requirements change.

Upstream references:

- MATE installation and session guidance: https://wiki.mate-desktop.org/introduction/installation/
- MATE 1.28 release overview: https://planet.mate-desktop.org/
- Official MATE source releases: https://pub.mate-desktop.org/releases/1.28/
- MATE desktop release history: https://github.com/mate-desktop/mate-desktop/releases
- LFS 13.1-systemd book: https://www.linuxfromscratch.org/lfs/view/stable-systemd/

## Validation

Run:

```bash
bash scripts/lfs/validate-mate-stack.sh
```

This checks manifest structure, duplicate entries and required targets. It
does not claim that MATE has been compiled, installed or booted.
