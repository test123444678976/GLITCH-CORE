#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDER="$ROOT/scripts/lfs/build-chapter8-iana-etc.sh"
fail(){ echo "ERROR: $*" >&2; exit 1; }
bash -n "$BUILDER" || fail "Invalid builder syntax."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$T/lfs"; mkdir -p "$L"/{sources,tools,etc}
touch "$L/tools/.glitchcore-chapter7-temporary-tools-complete" "$L/tools/.glitchcore-ch8-man-pages-complete"
mkdir -p "$T/src/iana-etc-20260805"
printf 'http 80/tcp\n' > "$T/src/iana-etc-20260805/services"
printf 'ip 0 IP\n' > "$T/src/iana-etc-20260805/protocols"
tar -czf "$L/sources/iana-etc-20260805.tar.gz" -C "$T/src" iana-etc-20260805
(cd "$L/sources" && md5sum iana-etc-20260805.tar.gz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-iana-etc-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-manpages"; rm "$T/no-manpages/tools/.glitchcore-ch8-man-pages-complete"
if bash "$BUILDER" --check-only "$T/no-manpages" >/dev/null 2>&1; then fail "Missing Man-pages prerequisite accepted."; fi
cp -a "$L" "$T/no-protocols"; mkdir -p "$T/bad/iana-etc-20260805"; printf 'http 80/tcp\n' > "$T/bad/iana-etc-20260805/services"; tar -czf "$T/no-protocols/sources/iana-etc-20260805.tar.gz" -C "$T/bad" iana-etc-20260805; (cd "$T/no-protocols/sources" && md5sum iana-etc-20260805.tar.gz > md5sums)
if bash "$BUILDER" --check-only "$T/no-protocols" >/dev/null 2>&1; then fail "Archive missing protocols accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/iana-etc-20260805.tar.gz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
echo "Chapter 8.4 IANA-etc preflight tests: OK"
