# GLITCH//CORE — LFS 13.1-systemd Chapter 7 implementation plan

## Scope and status

This document records the Chapter 7 implementation and its acceptance criteria.
The host-side builder is `scripts/lfs/build-toolchain-chapter7.sh`; its
preflight regression suite is `scripts/lfs/test-toolchain-chapter7.sh`.
The LFS workflow now includes a Chapter 7 build job after the chroot bootstrap.

The original bootstrap checkpoint explicitly recorded
`CHAPTER7_TEMPORARY_PACKAGES=not-built`. In run
[45016697312](https://github.com/test123444678976/GLITCH-CORE/actions/runs/45016697312),
the build step completed all eight package recipes inside chroot and wrote
the package markers, but the following host-side verification failed when it
executed the target Python binary outside the LFS rootfs. The packages were
built in that job, but no final checkpoint artifact was uploaded. The
verification now runs the target tools inside chroot, and
`.github/workflows/lfs-chapter7-recovery.yml` can resume from the successful
Chapter 6 artifact without rebuilding Chapters 5 and 6. Final completion still
requires a successful verification and uploaded Chapter 7 checkpoint.

## Pinned package set

The versions below match the released LFS 13.1-systemd book and
`config/lfs-toolchain.lock`. Preserve the uppercase initial letter in
`Python-3.14.7.tar.xz`.

| Order | Package | Source archive | Purpose |
|---:|---|---|---|
| 1 | Gettext 1.0 | `gettext-1.0.tar.xz` | Temporary `msgfmt`, `msgmerge`, `xgettext` |
| 2 | Bison 3.8.2 | `bison-3.8.2.tar.xz` | Parser generator |
| 3 | Perl 5.44.0 | `perl-5.44.0.tar.xz` | Perl runtime and shared libperl |
| 4 | Zlib 1.3.2 | `zlib-1.3.2.tar.gz` | Compression library |
| 5 | mpdecimal 4.0.1 | `mpdecimal-4.0.1.tar.gz` | Decimal arithmetic library for Python |
| 6 | Python 3.14.7 | `Python-3.14.7.tar.xz` | Temporary Python runtime |
| 7 | Texinfo 7.3 | `texinfo-7.3.tar.xz` | Info documentation tools |
| 8 | Util-linux 2.42.2 | `util-linux-2.42.2.tar.xz` | Essential system utilities |

All eight archives must be present in the official LFS source manifests and
pass checksum verification before the chroot build begins.

## Upstream recipe requirements

Build as root inside the isolated LFS chroot, following the release book.
Use the exact source versions above.

1. **Gettext** — configure with `--disable-shared`; build with `make`;
   install only `msgfmt`, `msgmerge`, and `xgettext` from
   `gettext-tools/src/` into `/usr/bin`.
2. **Bison** — configure with
   `--prefix=/usr --docdir=/usr/share/doc/bison-3.8.2`; run
   `make` and `make install`.
3. **Perl** — run `sh Configure -des` with
   `prefix=/usr`, `vendorprefix=/usr`, `useshrplib`, and the
   LFS 5.44 module paths under `/usr/lib/perl5/5.44/{core_perl,site_perl,vendor_perl}`;
   then run `make` and `make install`.
4. **Zlib** — configure with `--prefix=/usr`; run `make` and
   `make install`; remove the temporary static archive `/usr/lib/libz.a`.
5. **mpdecimal** — configure with
   `--prefix=/usr --disable-static --docdir=/usr/share/doc/mpdecimal-4.0.1`;
   run `make` and `make install`.
6. **Python** — configure with
   `--prefix=/usr --enable-shared --without-ensurepip --without-static-libpython`;
   run `make` and `make install`. Missing optional modules that depend
   on later Chapter 8 packages must not be mistaken for a failed top-level build.
7. **Texinfo** — configure with `--prefix=/usr`; run `make` and
   `make install`.
8. **Util-linux** — create `/var/lib/hwclock`; configure with
   `--libdir=/usr/lib --runstatedir=/run`,
   disable chfn/chsh, login, nologin, su, setpriv, runuser, pylibmount,
   static libraries and liblastlog2; use `--without-python`,
   `ADJTIME_PATH=/var/lib/hwclock/adjtime`, and
   `--docdir=/usr/share/doc/util-linux-2.42.2`; run `make` and
   `make install`.

## Required implementation safeguards

- The host-side orchestrator must require Linux x86_64, root privileges,
  an absolute non-root target directory, and the Chapter 6 completion marker.
- Reject symlinked or unexpected target paths before mounting or writing.
- Verify all source archives against the downloaded official checksum
  manifest before entering chroot.
- Mount only the required virtual filesystems; track each successful mount
  and unmount it in a trap, in reverse order.
- Use a clean chroot environment with a controlled PATH and locale.
- Build packages in the listed order and create one completion marker per
  package only after its install step succeeds.
- Make reruns explicit and safe: skip only packages with valid completion
  markers; never treat an empty marker as proof of installed files.
- Verify the installed commands/libraries and write provenance that lists
  the exact book, package versions, source checksums, commit and job.
- Package the resulting rootfs checkpoint while preserving numeric ownership,
  permissions and symlinks.
- Keep Chapter 8 and the graphical desktop out of this checkpoint.

## CI acceptance criteria

The Chapter 7 workflow job must not pass unless:

- all eight source archives pass checksum validation;
- all eight package build/install steps complete in order;
- expected commands and libraries exist inside the target rootfs;
- every per-package marker and the Chapter 7 completion marker exist;
- a chroot smoke test can execute the newly installed tools;
- the checkpoint archive can be listed and extracted while preserving
  ownership, permissions and symlinks;
- provenance clearly distinguishes a Chapter 7 temporary-tools checkpoint
  from a complete LFS system or bootable ISO.

The builder completed all eight package recipes in the first integrated
attempt; its internal chroot checks passed. The separate workflow verification
then exposed a host-versus-target dynamic-library lookup mistake for Python.
The main workflow verification was corrected to run target binaries inside
chroot, and a recovery workflow was added to rebuild Chapter 7 from the
existing Chapter 6 checkpoint and publish a verified artifact.

## Official references

- [LFS 13.1-systemd — Chapter 7](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/chapter07.html)
- [Gettext](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/gettext.html)
- [Bison](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/bison.html)
- [Perl](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/perl.html)
- [Zlib](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/zlib.html)
- [mpdecimal](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/mpdecimal.html)
- [Python](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/Python.html)
- [Texinfo](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/texinfo.html)
- [Util-linux](https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter07/util-linux.html)
