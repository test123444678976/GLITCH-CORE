# GLITCH//CORE — LFS build environment

## Target

- Architecture: x86_64
- Base: Linux From Scratch 13.1-systemd
- Init: systemd
- Build reference: [official LFS systemd book](https://www.linuxfromscratch.org/lfs/view/systemd/)

The host is only a temporary build environment. It does not become the
GLITCH//CORE base distribution. LFS itself is built from source in an
isolated target filesystem.

## Host preflight

Run the read-only preflight from a Linux build host:

```bash
bash scripts/lfs/check-host.sh
```

The script checks architecture, Linux, essential build commands, compiler
and linker versions, kernel version, and recommended CPU/RAM. It does not
install software or modify partitions, filesystems, mounts, or the host.

## Source preparation

Run the existing source preparation step:

```bash
bash scripts/build-lfs.sh
```

It downloads the official source manifest and archives and verifies the
published checksums. It does not compile the system.

## Chapter 5: first cross-toolchain stages

The first actual compilation steps are Binutils Pass 1 followed by GCC
Pass 1. The implementation is in
`scripts/lfs/build-toolchain-pass1.sh`.

Prepare a dedicated LFS target directory and its `tools` directory as
described in the official LFS book. The `tools` directory must be writable
by the unprivileged build account. Do not use the host's root filesystem as
the target, and do not run the compiler script as root.

With the LFS build account and its clean LFS environment active, set the target and put the cross-tools first in `PATH`:

```bash
export LFS=/absolute/path/to/work-lfs/lfs
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH="$LFS/tools/bin:$PATH"
export JOBS=4

bash scripts/lfs/build-toolchain-pass1.sh binutils
bash scripts/lfs/build-toolchain-pass1.sh gcc
```

The GCC Pass 1 step also applies the x86_64 library-directory adjustment
required by the LFS 13.1 instructions. The script does not install host
packages or modify the host system.

Or run both stages in order:

```bash
LFS=/absolute/path/to/work-lfs/lfs JOBS=4 bash scripts/lfs/build-toolchain-pass1.sh all
```

The script is x86_64-only, requires the verified source archives, checks
that it is not running as root, and writes only under the LFS workspace.
Successful stages create marker files in `$LFS/tools` so completed stages
are skipped on later runs. A failed stage can be re-run after correcting
the cause; inspect its build directory and logs first.

## Build milestones

1. Host preflight and preparation of a dedicated LFS workspace.
2. Download the LFS source manifest and verify checksums.
3. Build Binutils Pass 1 and GCC Pass 1.
4. Build Linux API headers, Glibc, and target Libstdc++.
5. Build temporary tools (LFS Chapter 6).
6. Enter chroot and build the final userspace (Chapters 7–8).
7. Configure systemd, networking, filesystem layout and kernel (Chapters 9–10).
8. Boot-test the base system in QEMU.
9. Add BLFS components for graphics and MATE only after the base boots.

The LFS book is updated over time. Keep package versions, source manifests,
and build instructions pinned to the same exact LFS book revision for a
reproducible build. Review the official book before updating any version.

## Safety and build isolation

- Keep the current BusyBox ISO as the rescue/bootstrap prototype.
- Never run partition-formatting commands against a developer's normal disk.
- Use a dedicated virtual disk or isolated build volume for the target.
- Do not run package compilation as root when the LFS book specifies the
  unprivileged `lfs` user.
- Keep all new work on `feature/mate-desktop` until it is reviewed and tested.
