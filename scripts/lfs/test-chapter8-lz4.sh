#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-lz4.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc,usr/bin,usr/lib,dev,proc,sys,run}
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete .glitchcore-ch8-bzip2-complete .glitchcore-ch8-xz-complete; do touch "$L/tools/$m"; done
for b in bash make gcc; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/lz4-1.10.0/lib"
printf 'all:\n\t@true\n' > "$T/src/lz4-1.10.0/Makefile"
printf 'all:\n\t@true\n' > "$T/src/lz4-1.10.0/lib/Makefile"
tar -czf "$L/sources/lz4-1.10.0.tar.gz" -C "$T/src" lz4-1.10.0
(cd "$L/sources" && md5sum lz4-1.10.0.tar.gz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-lz4-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-xz"; rm "$T/no-xz/tools/.glitchcore-ch8-xz-complete"
if bash "$BUILDER" --check-only "$T/no-xz" >/dev/null 2>&1; then fail "Missing Xz checkpoint accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/lz4-1.10.0.tar.gz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.9 LZ4 preflight tests: OK"
