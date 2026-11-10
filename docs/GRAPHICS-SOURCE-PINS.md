# GLITCH//CORE — graphics source pin provenance

This document records the origin of the four initial entries in
`config/graphics-sources.lock`. The lock is a **partial source set**, not a
complete dependency closure and not a package build recipe.

| Package | Pinned version | Archive | SHA-256 source |
|---|---:|---|---|
| Mesa | 26.2.6 | `mesa-26.2.6.tar.xz` | [Mesa 26.2.6 release notes](https://docs.mesa3d.org/relnotes/26.2.6.html) |
| libdrm | 2.4.134 | `libdrm-2.4.134.tar.xz` | [libdrm 2.4.134 release announcement](https://lwn.net/Articles/1075398/) |
| Xorg server | 21.1.25 | `xorg-server-21.1.25.tar.xz` | [X.Org upstream archive](https://xorg.freedesktop.org/archive/individual/xserver/) and [independent distribution distinfo](https://lists.freebsd.org/archives/dev-commits-ports-branches/2026-October/015677.html) |
| xorgproto | 2026.1 | `xorgproto-2026.1.tar.xz` | [xorgproto 2026.1 release announcement](https://www.mail-archive.com/xorg%40lists.x.org/msg08348.html) |

## Integrity policy

- Downloads are restricted to HTTPS and the three upstream archive hosts
  explicitly allowed by the validator.
- SHA-256 is checked before an archive is moved into the destination.
- Existing regular files are reused only when their digest matches.
- Redirects must remain HTTPS; symlink destinations are rejected.
- The lock validator rejects duplicate names/archives, malformed digests,
  HTTP URLs, unapproved hosts and URL/archive filename mismatches.

## Remaining work

The lock currently covers only Mesa, libdrm, Xorg server and xorgproto.
It does not pin the rest of the X11 libraries, input stack, LLVM/Clang,
Wayland dependencies, build helpers, patches or package-specific configure
options. Do not treat it as permission to run a full graphics build yet.
Upstream signatures should also be verified against trusted maintainer keys
before release packaging is enabled.
