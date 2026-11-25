#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-xz.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc,usr/bin,usr/lib,dev,proc,sys,run}
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete .glitchcore-ch8-bzip2-complete; do touch "$L/tools/$m"; done
for b in bash make gcc; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/xz-5.8.3"
printf 'all:\n\t@true\n' > "$T/src/xz-5.8.3/Makefile.in"
printf '#!/bin/sh\nexit 0\n' > "$T/src/xz-5.8.3/configure"
chmod 755 "$T/src/xz-5.8.3/configure"
tar -cJf "$L/sources/xz-5.8.3.tar.xz" -C "$T/src" xz-5.8.3
(cd "$L/sources" && md5sum xz-5.8.3.tar.xz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-xz-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-bzip"; rm "$T/no-bzip/tools/.glitchcore-ch8-bzip2-complete"
if bash "$BUILDER" --check-only "$T/no-bzip" >/dev/null 2>&1; then fail "Missing Bzip2 checkpoint accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/xz-5.8.3.tar.xz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.8 Xz preflight tests: OK"
