# Chapter 8.4 IANA-etc trigger

This marker starts the next restartable LFS Chapter 8 package after the successful Chapter 8.3 Man-pages checkpoint from workflow run 45586451667.

The workflow restores the Man-pages checkpoint, validates the official IANA-etc 20260805 source archive against the LFS checksum manifest, copies the official services and protocols data into the target /etc directory, verifies both installed files, and uploads a new Chapter 8.4 checkpoint.

The installer validates the current IANA protocol-number-zero entry as `hopopt 0 HOPOPT`. The upstream IANA generator derives this record from the protocol-numbers registry; it must not be incorrectly treated as the legacy `ip 0 IP` entry.

The checkpoint packager and workflow validate archive listings through temporary files rather than `tar | grep -q`, avoiding premature pipe closure under `pipefail`.

The installer and regression fixture now validate the canonical services-file shape (`service port/tcp` or `service port/udp`) rather than looking for the protocol token as a standalone word. The regression suite also rejects malformed service records before accepting the checkpoint.
