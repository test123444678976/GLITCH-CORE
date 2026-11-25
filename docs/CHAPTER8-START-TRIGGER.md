# Chapter 8 start trigger

This marker starts the Chapter 8.3 Man-pages build on feature/mate-desktop using the verified Chapter 7 checkpoint from workflow run 45187793658.

The builder preflight was corrected to avoid a pipefail/SIGPIPE false failure while inspecting the xz archive, and its chroot mount cleanup now handles already-unmounted paths safely. Re-run the Chapter 8.3 workflow against the same verified Chapter 7 checkpoint.

The checkpoint packager and workflow now verify the archive marker without grep -q, preventing tar from receiving SIGPIPE under pipefail. Retry Chapter 8.3 from the verified Chapter 7 checkpoint.

Retry requested on 2026-11-25 after correcting the checkpoint archive listing check to avoid the tar|grep -q SIGPIPE failure under pipefail. Continue from the verified Chapter 7 artifact (source run 45187793658); do not rebuild Chapter 7.
