# GLITCH//CORE — LFS Chapter 8.10 Zstd 1.5.7

Branch: `feature/mate-desktop`

This manual workflow consumes a successful Chapter 8.9 artifact named
`glitch-core-lfs-chapter8-lz4-x86_64`. It restores the checkpoint, verifies
Chapter 7 and Chapter 8.3–8.9 markers and provenance, runs the Zstd preflight
regression suite, then builds Zstd inside the restored LFS chroot.

The builder follows LFS 13.1-systemd:
`make prefix=/usr`, `make check`, `make prefix=/usr install`, and removes
`/usr/lib/libzstd.a`. LFS notes that some test output may say "failed";
only actual `FAIL` results are test failures, and the test suite must pass.

The workflow uploads `glitch-core-lfs-chapter8-zstd-x86_64` only after
installation checks and a compression/decompression smoke test pass.

## Dispatch

Do not dispatch until a successful Chapter 8.9 LZ4 run has uploaded its
checkpoint artifact. Supply that successful run ID as `source_run_id`.
