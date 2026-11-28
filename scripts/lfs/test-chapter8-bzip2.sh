#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-bzip2.sh"
WORKFLOW="$ROOT/.github/workflows/lfs-chapter8-bzip2.yml"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ -s "$WORKFLOW" ]] || fail "Bzip2 workflow is missing or empty."
grep -Fq 'run-id: ${{ inputs.source_run_id }}' "$WORKFLOW" || fail "Bzip2 workflow does not use the supplied Zlib run ID."
grep -Fq 'SOURCE_RUN_ID: ${{ inputs.source_run_id }}' "$WORKFLOW" || fail "Bzip2 workflow does not validate its source run ID."
grep -Fq '[[ "$SOURCE_RUN_ID" =~ ^[0-9]+$ ]]' "$WORKFLOW" || fail "Bzip2 workflow accepts non-numeric source run IDs."
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc,usr/bin,usr/lib,dev,proc,sys,run}
for m in .glitchcore-chapter7-temporary-tools-complete .glitchcore-ch8-man-pages-complete .glitchcore-ch8-iana-etc-complete .glitchcore-ch8-glibc-complete .glitchcore-ch8-zlib-complete; do touch "$L/tools/$m"; done
for b in bash make gcc; do printf '#!/bin/sh\nexit 0\n' > "$L/usr/bin/$b"; chmod 755 "$L/usr/bin/$b"; done
ln -s usr/bin "$L/bin"
mkdir -p "$T/src/bzip2-1.0.8"
printf 'all:\n\t@true\n' > "$T/src/bzip2-1.0.8/Makefile"
printf 'all:\n\t@true\n' > "$T/src/bzip2-1.0.8/Makefile-libbz2_so"
tar -czf "$L/sources/bzip2-1.0.8.tar.gz" -C "$T/src" bzip2-1.0.8
printf 'fixture patch\n' > "$L/sources/bzip2-1.0.8-install_docs-1.patch"
(cd "$L/sources" && md5sum bzip2-1.0.8.tar.gz bzip2-1.0.8-install_docs-1.patch > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-bzip2-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-zlib"; rm "$T/no-zlib/tools/.glitchcore-ch8-zlib-complete"
if bash "$BUILDER" --check-only "$T/no-zlib" >/dev/null 2>&1; then fail "Missing Zlib checkpoint accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/bzip2-1.0.8.tar.gz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
cp -a "$L" "$T/bad-patch-sum"; echo tamper >> "$T/bad-patch-sum/sources/bzip2-1.0.8-install_docs-1.patch"
if bash "$BUILDER" --check-only "$T/bad-patch-sum" >/dev/null 2>&1; then fail "Bad patch checksum accepted."; fi
echo "Chapter 8.7 Bzip2 preflight tests: OK"
