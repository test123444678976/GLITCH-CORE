#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-glibc.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc,usr/bin,usr/share,dev,proc,sys,run}
touch "$L/tools/.glitchcore-chapter7-temporary-tools-complete" "$L/tools/.glitchcore-ch8-man-pages-complete" "$L/tools/.glitchcore-ch8-iana-etc-complete"
for b in bash make gcc; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/glibc-2.44"; printf 'all:\n\t@true\n' > "$T/src/glibc-2.44/Makefile"; printf '#!/bin/sh\nexit 0\n' > "$T/src/glibc-2.44/configure"
tar -cJf "$L/sources/glibc-2.44.tar.xz" -C "$T/src" glibc-2.44
printf 'fixture patch fhs\n' > "$L/sources/glibc-fhs-1.patch"
printf 'fixture patch fixes\n' > "$L/sources/glibc-2.44-upstream_fixes-1.patch"
(cd "$L/sources" && md5sum glibc-2.44.tar.xz glibc-fhs-1.patch glibc-2.44-upstream_fixes-1.patch > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-glibc-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-iana"; rm "$T/no-iana/tools/.glitchcore-ch8-iana-etc-complete"
if bash "$BUILDER" --check-only "$T/no-iana" >/dev/null 2>&1; then fail "Missing IANA checkpoint accepted."; fi
cp -a "$L" "$T/no-patch"; rm "$T/no-patch/sources/glibc-2.44-upstream_fixes-1.patch"
if bash "$BUILDER" --check-only "$T/no-patch" >/dev/null 2>&1; then fail "Missing patch accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/glibc-2.44.tar.xz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.5 Glibc preflight tests: OK"
