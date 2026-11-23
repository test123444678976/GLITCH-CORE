#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-man-pages.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,usr/bin,usr/share,dev,proc,sys,run}
touch "$L/tools/.glitchcore-chapter7-temporary-tools-complete"
for b in bash make; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/man-pages-6.18/man3"; echo fixture > "$T/src/man-pages-6.18/man3/crypt.3"
tar -cJf "$L/sources/man-pages-6.18.tar.xz" -C "$T/src" man-pages-6.18
(cd "$L/sources" && md5sum man-pages-6.18.tar.xz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-man-pages-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/missing"; rm "$T/missing/sources/man-pages-6.18.tar.xz"
if bash "$BUILDER" --check-only "$T/missing" >/dev/null 2>&1; then fail "Missing source accepted."; fi
cp -a "$L" "$T/no-ch7"; rm "$T/no-ch7/tools/.glitchcore-chapter7-temporary-tools-complete"
if bash "$BUILDER" --check-only "$T/no-ch7" >/dev/null 2>&1; then fail "Incomplete Chapter 7 accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/man-pages-6.18.tar.xz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.3 Man-pages preflight tests: OK"
