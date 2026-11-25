# GLITCH//CORE — LFS Chapter 8.9 LZ4 1.10.0

Branch: `feature/mate-desktop`

This manual workflow consumes a successful Chapter 8.8 artifact named
`glitch-core-lfs-chapter8-xz-x86_64`. It restores the checkpoint, verifies the
Chapter 7 and Chapter 8.3–8.8 markers and provenance, runs the LZ4 preflight
regression suite, then builds LZ4 inside the restored LFS chroot.

The builder follows the LFS 13.1-systemd recipe:
`make BUILD_STATIC=no PREFIX=/usr`, `make -j1 check`, and
`make BUILD_STATIC=no PREFIX=/usr install`.

The workflow uploads `glitch-core-lfs-chapter8-lz4-x86_64` only after
installation checks and a compression/decompression smoke test pass.

## Dispatch

Do not dispatch until a successful Chapter 8.8 Xz run has uploaded its
checkpoint artifact. Supply that successful run ID as `source_run_id`.
