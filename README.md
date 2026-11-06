# GLITCH//CORE

Experimental x86_64 Linux distribution project.

## Important: what this first ZIP builds

This is a **bootable prototype**, not a complete Linux From Scratch (LFS)
system yet. GitHub Actions downloads and compiles an upstream Linux kernel
and static BusyBox, creates a small initramfs, and packages everything into
a bootable GRUB ISO.

The first milestone is to boot into a BusyBox shell in QEMU. Later milestones
can replace this bootstrap root filesystem with a full LFS-built userspace.

## Build without Linux on your public PC

You only need a browser and permission to use GitHub:

1. Create a GitHub repository named `GLITCH-CORE`.
2. Extract this ZIP on Windows.
3. Upload the **contents** of the `GLITCH-CORE` folder to the repository.
   Make sure `.github/workflows/build.yml` is included. If GitHub's web
   uploader hides `.github`, create the folders and file using
   **Add file → Create new file**, entering
   `.github/workflows/build.yml` as the filename, then copy its contents
   from this ZIP.
4. Open the repository's **Actions** tab.
5. Select **Build GLITCH//CORE ISO** and press **Run workflow**.
6. Wait for the workflow to finish successfully.
7. Open the completed workflow run, find **Artifacts**, and download
   `glitch-core-iso`. It contains `GLITCH-CORE.iso`.

A push to the `main` branch also starts a build automatically.

## Test with QEMU on Windows

If QEMU is already available and permitted on the PC, open Command Prompt
in the folder containing the ISO and run:

```bat
qemu-system-x86_64.exe -m 1024 -cdrom GLITCH-CORE.iso -boot d
```

If the QEMU executable is not on PATH, use its full installation path.

## Project layout

- `.github/workflows/build.yml` — cloud build workflow
- `scripts/build.sh` — builds kernel, BusyBox, initramfs and ISO
- `config/` — project configuration placeholders
- `rootfs/` — notes about generated root filesystem
- `boot/` — notes about generated boot files

## Notes

- Build requires internet access on the GitHub-hosted runner.
- The workflow uses Ubuntu 24.04 as a temporary cloud build environment;
  it does not install Linux on your Windows computer.
- This prototype targets x86_64 and is intended for QEMU testing.
- Kernel and BusyBox versions are pinned in `scripts/build.sh`.
- This is not yet a full LFS toolchain, package manager, desktop, or installer.
