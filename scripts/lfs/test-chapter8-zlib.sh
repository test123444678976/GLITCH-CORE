#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/lfs-chapter8-zlib.yml"
grep -Fq 'run-id: ${{ inputs.source_run_id }}' "$WORKFLOW" || fail "Zlib workflow does not use the supplied source run ID."
if grep -Fq "45616626689" "$WORKFLOW"; then fail "Stale failed Glibc run ID remains in Zlib workflow."; fi
BUILDER="$ROOT/scripts/lfs/build-chapter8-zlib.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc,usr/bin,usr/lib,dev,proc,sys,run}
touch "$L/tools/.glitchcore-chapter7-temporary-tools-complete" "$L/tools/.glitchcore-ch8-man-pages-complete" "$L/tools/.glitchcore-ch8-iana-etc-complete" "$L/tools/.glitchcore-ch8-glibc-complete"
for b in bash make gcc; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/zlib-1.3.2"; printf 'all:\n\t@true\n' > "$T/src/zlib-1.3.2/Makefile"; printf '#!/bin/sh\nexit 0\n' > "$T/src/zlib-1.3.2/configure"
tar -czf "$L/sources/zlib-1.3.2.tar.gz" -C "$T/src" zlib-1.3.2
(cd "$L/sources" && md5sum zlib-1.3.2.tar.gz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
JOBS=3 bash "$BUILDER" --check-only "$L" >/dev/null || fail "Explicit JOBS override rejected."
if JOBS=0 bash "$BUILDER" --check-only "$L" >/dev/null 2>&1; then fail "Invalid JOBS value accepted."; fi
[[ ! -e "$L/tools/.glitchcore-ch8-zlib-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-glibc"; rm "$T/no-glibc/tools/.glitchcore-ch8-glibc-complete"
if bash "$BUILDER" --check-only "$T/no-glibc" >/dev/null 2>&1; then fail "Missing Glibc checkpoint accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/zlib-1.3.2.tar.gz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.6 Zlib preflight tests: OK"
