# Mesa target build — GLITCH//CORE

`scripts/lfs/build-mesa-target.sh` is the first actual target-rootfs graphics
builder. Unlike the existing host-side libdrm staging jobs, it runs Meson,
Ninja, the compiler, and installation from inside the selected LFS rootfs.
It refuses the host root and checks the pinned Mesa archive before extraction.

## Required target prerequisites

The LFS rootfs must already contain Meson, Ninja, Python 3, pkg-config,
libdrm development headers/libraries, and the normal LFS compiler/runtime
toolchain. These prerequisites must themselves be built for and installed
inside the target rootfs. A host-side DESTDIR artifact is not a substitute.

## Initial x86_64 driver profile

- X11 and Wayland platform support
- Gallium `softpipe` for a software-rendering fallback
- Gallium `virgl` for QEMU virtio-gpu/virgl environments
- GLX, EGL, GBM, desktop OpenGL and GLES 2
- LLVM and Vulkan disabled for this first profile to avoid silently depending
  on components that are not yet in the LFS target

The build records source provenance at
`/usr/share/glitch-core/mesa-build-info` and writes
`/var/lib/glitch-core-mesa-installed` only after installation checks pass.

This is not yet a complete graphics stack: Xorg, GTK, MATE, LightDM and their
dependencies still need target-rootfs builders and runtime testing. The
Raspberry Pi ARM64 driver profile must be built separately later; this x86_64
profile is not the Pi image.
