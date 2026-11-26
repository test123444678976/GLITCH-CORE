# GLITCH//CORE LFS Chapter 8.5 — Glibc 2.44

Starts the sequential Chapter 8.5 build from verified Chapter 8.4 run
45596825403. The builder verifies Glibc and both pinned patches against the
LFS md5sums manifest, applies the FHS and upstream-fixes patches, configures
the native LFS build, runs the complete critical Glibc test suite (allowing only the LFS-documented `io/tst-lchmod` chroot descriptor-path failure when its diagnostic matches), installs UTF-8
locales and records provenance.

No Chapter 8.5 checkpoint is published unless the complete test suite finishes with zero unexpected failures, the target
libc and loader tools are present, and the completion marker is written.

Diagnostic rerun: preserve the complete make-check log as an artifact if the
test suite fails, so all failing test details can be investigated.

Failure diagnostics now also archive the individual `.out` and `.test-result` files for every test reported as `FAIL`, alongside the complete `make check` log. This allows the next investigation to identify the actual assertion or environment error for each failing test.

The chroot setup now mounts devpts at `/dev/pts` (`gid=5,mode=0620`) before `make check`, so terminal and pseudo-terminal tests use the LFS chroot's own devpts instance. The mount is explicitly unmounted during cleanup.

The only accepted test-suite exception is `io/tst-lchmod`, which LFS 13.1 documents as a known chroot-environment failure. The builder requires that it be the sole failed test, requires at least 6000 passing tests, and checks the test output for the descriptor-path mismatch. Any other failure remains fatal.
