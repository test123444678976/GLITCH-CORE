# Chapter 8.4 IANA-etc trigger

This marker starts the next restartable LFS Chapter 8 package after the successful Chapter 8.3 Man-pages checkpoint from workflow run 45365222640.

The workflow restores the Man-pages checkpoint, validates the official IANA-etc 20260805 source archive against the LFS checksum manifest, copies the official services and protocols data into the target /etc directory, verifies both installed files, and uploads a new Chapter 8.4 checkpoint.

This is a separate trigger from the Chapter 8.3 workflow so it does not rebuild Man-pages from Chapter 7.

Retry note (2026-11-25): the IANA-etc installer now validates the IP protocol number 0 entry case-insensitively, matching the canonical uppercase protocol name in the upstream data. The test fixture now covers `IP 0 IP`. Retry from the already verified Chapter 8.3 checkpoint run 45365222640.
