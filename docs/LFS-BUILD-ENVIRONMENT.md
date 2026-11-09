# GLITCH//CORE — LFS build environment

## Target

- Architecture: x86_64
- Base: Linux From Scratch 13.1-systemd
- Init: systemd
- Build reference: [official LFS 13.1-systemd book](https://www.linuxfromscratch.org/lfs/view/13.1-systemd/)

The host is only a temporary build environment. It does not become the
GLITCH//CORE base distribution. LFS itself is built from source in an
isolated target filesystem.

## First safe step: check the host

Run the read-only preflight from a Linux build host:

```bash
bash scripts/lfs/check-host.sh
```

The script checks architecture, Linux, essential build commands, compiler
and linker versions, kernel version, and recommended CPU/RAM. It does not
install software or modify partitions, filesystems, mounts, or the host.

The LFS editors recommend at least four CPU cores and 8 GiB RAM. GCC newer
than 16.2.0 and Binutils newer than 2.47 are not tested for LFS 13.1.

## Build stages

1. Host preflight and preparation of a dedicated LFS workspace.
2. Download the exact LFS 13.1-systemd source manifest and verify checksums.
3. Create the LFS user and isolated build environment.
4. Build the cross-toolchain (LFS Chapter 5).
5. Build temporary tools (Chapter 6).
6. Enter the chroot and build the final userspace (Chapters 7–8).
7. Configure systemd, networking, filesystem layout and kernel (Chapters 9–10).
8. Boot-test the base system in QEMU.
9. Add BLFS components for graphics and MATE only after the base boots.

The current `scripts/build-lfs.sh` is still only the source-download and
checksum-verification stage. It is not yet a compiler or complete LFS build
orchestrator. We will implement and test the stages incrementally rather than
claiming that a downloader creates an operating system.

## Safety and build isolation

- Keep the current BusyBox ISO as the rescue/bootstrap prototype.
- Never run partition-formatting commands against a developer's normal disk.
- Use a dedicated virtual disk or isolated build volume for the target.
- Do not run package compilation as root when the LFS book specifies the
  unprivileged `lfs` user.
- Keep all new work on `feature/mate-desktop` until it is reviewed and tested.
