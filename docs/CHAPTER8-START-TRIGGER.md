# Chapter 8 start trigger

This marker starts the Chapter 8.3 Man-pages build on feature/mate-desktop using the verified Chapter 7 checkpoint from workflow run 45187793658.

The builder preflight was corrected to avoid a pipefail/SIGPIPE false failure while inspecting the xz archive, and its chroot mount cleanup now handles already-unmounted paths safely. Re-run the Chapter 8.3 workflow against the same verified Chapter 7 checkpoint.
