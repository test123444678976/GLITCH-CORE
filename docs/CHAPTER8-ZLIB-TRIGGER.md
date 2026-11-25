# GLITCH//CORE LFS Chapter 8.6 — Zlib 1.3.2

This manually dispatched workflow continues the official LFS 13.1-systemd Chapter 8 sequence after a successful Chapter 8.5 Glibc checkpoint.

## Gates

- Restore the glitch-core-lfs-chapter8-glibc-x86_64 artifact from a successful Glibc workflow run.
- Verify Chapter 7, Man-pages, IANA-etc, and Glibc checkpoint markers.
- Verify the official LFS source archive against the rootfs sources/md5sums manifest.
- Run shell/preflight regression tests.
- Build Zlib inside the target LFS chroot using the LFS recipe: ./configure --prefix=/usr, make, make check, make install, then remove /usr/lib/libz.a.
- Verify libz.so, zlib.h, pkg-config metadata, and the successful test log.
- Publish a Chapter 8.6 checkpoint only after all checks pass.

The workflow is intentionally manual: it must not start until Chapter 8.5 has produced its verified artifact. It does not modify the default branch or claim a bootable desktop ISO.
