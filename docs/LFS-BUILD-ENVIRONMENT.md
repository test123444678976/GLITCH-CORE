# GLITCH//CORE — LFS build environment

## Target

- Architecture: x86_64
- Base: Linux From Scratch 13.1-systemd
- Init: systemd
- Build reference: [official LFS systemd book](https://www.linuxfromscratch.org/lfs/view/stable-systemd/)

The host is only a temporary build environment. It does not become the
GLITCH//CORE base distribution. LFS is built from source in an isolated
target filesystem.

## Host preflight

Run the read-only preflight from a Linux build host:

```bash
bash scripts/lfs/check-host.sh
```

The script checks architecture, Linux, essential build commands, compiler
and linker versions, kernel version, and recommended CPU/RAM. It does not
install software or modify partitions, filesystems, mounts, or the host.

## Source preparation

Run the source preparation step:

```bash
bash scripts/build-lfs.sh
```

It downloads the official LFS 13.1-systemd source manifest and archives and
verifies their published MD5 checksums. Before downloading, it checks that
the manifest contains the pinned LFS 13.1 toolchain versions (Binutils 2.47
and GCC 16.2.0). It filters the legacy LFS-Bootscripts archive from both
download and checksum manifests because that package belongs to the System V
boot process, not the systemd edition.

The source-preparation job also tests the checksum-verified ncurses mirror
fallback. A mirror archive is accepted only when it matches the checksum
from the official LFS manifest. Source preparation does not compile or
install the operating system.

## Chapter 5: cross-toolchain

The Chapter 5 build is implemented by:

- `scripts/lfs/build-toolchain-pass1.sh`: Binutils Pass 1 and GCC Pass 1.
- `scripts/lfs/build-toolchain-chapter5.sh`: the complete Chapter 5 sequence,
  including Linux API headers, cross Glibc and target Libstdc++.

Prepare a dedicated LFS target directory and its `tools` directory as
described in the official LFS book. The workspace must be writable by the
unprivileged build account. Never use the host's root filesystem as the
target, and do not run the LFS build scripts as root.

For a local build, set the target and put the cross-tools first in `PATH`:

```bash
export LFS=/absolute/path/to/work-lfs/lfs
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH="$LFS/tools/bin:$PATH"
export JOBS=2

bash scripts/lfs/build-toolchain-chapter5.sh
```

The scripts verify source archives against the downloaded LFS checksum
manifest, reject unsafe workspace paths, and create completion markers
under `$LFS/tools`. A failed stage should be investigated from its build
logs before it is retried. Do not delete a checkpoint to conceal a failed
build.

## Chapter 6: temporary tools

The Chapter 6 implementation is
`scripts/lfs/build-toolchain-chapter6.sh`. It requires the verified Chapter 5
checkpoint and builds the LFS temporary tools, Binutils Pass 2 and GCC Pass 2.
The regression test is `scripts/lfs/test-toolchain-chapter6.sh`.

Chapter 6 is run in a separate CI job. It downloads the Chapter 5 checkpoint
as an artifact, reconstructs the isolated workspace, verifies the required
completion markers, then runs the Chapter 6 regression tests before building.
The Chapter 6 output is another checkpoint; it is not the final LFS rootfs.

## GitHub Actions

The LFS pipeline is the separate workflow
`.github/workflows/lfs-toolchain.yml`, named **GLITCH//CORE LFS 13.1
Toolchain**. It supports manual dispatch and push events on
`feature/mate-desktop` when one of its watched LFS scripts, tests, source
lock files or the workflow itself changes. It is independent of the
BusyBox rescue ISO workflow.

The workflow is split into three jobs:

1. **Prepare sources:** downloads the official LFS 13.1-systemd source set,
   verifies its manifest checksums and uploads
   `glitch-core-lfs-13.1-verified-sources`.
2. **Build Chapter 5:** consumes that source checkpoint, runs the Chapter 5
   regression tests, builds Binutils Pass 1, GCC Pass 1, Linux API headers,
   Glibc and Libstdc++, verifies the target compiler/runtime, and uploads
   `glitch-core-lfs-toolchain-chapter5-x86_64`.
3. **Build Chapter 6:** consumes the Chapter 5 checkpoint, runs the Chapter 6
   regression tests, builds temporary tools plus Binutils Pass 2 and GCC
   Pass 2, verifies the expected tools and markers, and uploads
   `glitch-core-lfs-toolchain-chapter6-x86_64`.

The workflow records runner resources and build provenance. Check each run's
job logs and artifact manifest rather than treating a green earlier job as
proof that later stages completed. Checkpoint artifacts currently have a
seven-day retention period.

## What these checkpoints do not mean

A successful Chapter 5 or Chapter 6 CI job means those stages were built and
verified in that isolated GitHub Actions workspace. It does **not** mean the
checkpoint is installed in the persistent GLITCH//CORE rootfs, that the
Chapter 7/8 final userspace exists, or that the system boots.

The following milestones remain separate:

1. Enter chroot and build the final userspace (Chapters 7–8).
2. Configure systemd, networking, filesystem layout and kernel (Chapters 9–10).
3. Boot-test the LFS base system in QEMU.
4. Build and install BLFS graphics, GTK and MATE components in the LFS target.
5. Integrate target-native dpkg/APT and test package operations inside that rootfs.
6. Produce and boot-test a desktop LFS ISO.

The MATE integration gate remains: first complete and boot-test the LFS base,
then provide the final target toolchain and development libraries, graphics
stack, D-Bus, GTK and desktop dependencies. MATE manifests and CI host-side
staging artifacts are not evidence that MATE is installed.

## Safety and build isolation

- Keep the current BusyBox ISO as the rescue/bootstrap prototype.
- Never run partition-formatting commands against a developer's normal disk.
- Use a dedicated virtual disk or isolated build volume for the target.
- Do not run package compilation as root when the LFS book specifies the
  unprivileged `lfs` user.
- Do not copy Debian/Ubuntu binaries from the CI host into the LFS target.
- Keep this work on `feature/mate-desktop` until it is reviewed and tested.
