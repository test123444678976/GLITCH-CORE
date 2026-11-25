# GLITCH//CORE — LFS Chapter 8.8 Xz trigger

This manual workflow must only be dispatched after a successful Chapter 8.7 Bzip2 run has uploaded
`glitch-core-lfs-chapter8-bzip2-x86_64`.

1. Open the [Xz workflow](https://github.com/test123444678976/GLITCH-CORE/actions/workflows/lfs-chapter8-xz.yml).
2. Select **Run workflow** on `feature/mate-desktop`.
3. Enter the run ID of the successful Chapter 8.7 Bzip2 workflow.
4. Confirm that the restore step verifies the Bzip2 checkpoint before building Xz.

The builder follows the LFS 13.1-systemd Xz 5.8.3 recipe: configure with shared-library-only output, run `make` and `make check`, install, and verify the command-line tools and liblzma runtime library.

Reference: https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter08/xz.html
