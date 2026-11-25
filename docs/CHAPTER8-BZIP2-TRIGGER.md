# GLITCH//CORE — LFS Chapter 8.7 Bzip2 trigger

This manual workflow must only be dispatched after a successful Chapter 8.6 Zlib run has uploaded the artifact
`glitch-core-lfs-chapter8-zlib-x86_64`.

1. Open the [Bzip2 workflow](https://github.com/test123444678976/GLITCH-CORE/actions/workflows/lfs-chapter8-bzip2.yml).
2. Select **Run workflow** on `feature/mate-desktop`.
3. Enter the run ID of the successful Chapter 8.6 Zlib workflow.
4. Confirm that the restore step verifies the Zlib marker and provenance before the Bzip2 build starts.

The builder follows the LFS 13.1-systemd Bzip2 1.0.8 recipe, including the documentation patch, shared-library build, compatibility symlinks, and a compression/decompression smoke test. The checkpoint is published only after all verification steps pass.

Reference: https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter08/bzip2.html
