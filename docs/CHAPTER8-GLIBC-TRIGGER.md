# GLITCH//CORE LFS Chapter 8.5 — Glibc 2.44

Starts the sequential Chapter 8.5 build from verified Chapter 8.4 run
45596825403. The builder verifies Glibc and both pinned patches against the
LFS md5sums manifest, applies the FHS and upstream-fixes patches, configures
the native LFS build, runs the critical Glibc test suite, installs UTF-8
locales and records provenance.

No Chapter 8.5 checkpoint is published unless make check passes, the target
libc and loader tools are present, and the completion marker is written.

Diagnostic rerun: preserve the complete make-check log as an artifact if the
test suite fails, so all failing test details can be investigated.
