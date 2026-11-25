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
printf 'hopopt 0 HOPOPT\n' > "$T/src/iana-etc-20260805/protocols"
tar -czf "$L/sources/iana-etc-20260805.tar.gz" -C "$T/src" iana-etc-20260805
(cd "$L/sources" && md5sum iana-etc-20260805.tar.gz > md5sums)
bash "$BUILDER" --check-only "$L" >/dev/null || fail "Valid preflight rejected."
[[ ! -e "$L/tools/.glitchcore-ch8-iana-etc-complete" ]] || fail "Check-only wrote marker."
cp -a "$L" "$T/no-manpages"; rm "$T/no-manpages/tools/.glitchcore-ch8-man-pages-complete"
if bash "$BUILDER" --check-only "$T/no-manpages" >/dev/null 2>&1; then fail "Missing Man-pages prerequisite accepted."; fi
cp -a "$L" "$T/no-protocols"; mkdir -p "$T/bad/iana-etc-20260805"; printf 'http 80/tcp\n' > "$T/bad/iana-etc-20260805/services"; tar -czf "$T/no-protocols/sources/iana-etc-20260805.tar.gz" -C "$T/bad" iana-etc-20260805; (cd "$T/no-protocols/sources" && md5sum iana-etc-20260805.tar.gz > md5sums)
if bash "$BUILDER" --check-only "$T/no-protocols" >/dev/null 2>&1; then fail "Archive missing protocols accepted."; fi
cp -a "$L" "$T/no-service-record"; mkdir -p "$T/bad-service/iana-etc-20260805"; printf 'http 80\\n' > "$T/bad-service/iana-etc-20260805/services"; printf 'hopopt 0 HOPOPT\\n' > "$T/bad-service/iana-etc-20260805/protocols"; tar -czf "$T/no-service-record/sources/iana-etc-20260805.tar.gz" -C "$T/bad-service" iana-etc-20260805; (cd "$T/no-service-record/sources" && md5sum iana-etc-20260805.tar.gz > md5sums)
if bash "$BUILDER" "$T/no-service-record" >/dev/null 2>&1; then fail "Malformed services record accepted."; fi
cp -a "$L" "$T/bad-sum"; echo tamper >> "$T/bad-sum/sources/iana-etc-20260805.tar.gz"
if bash "$BUILDER" --check-only "$T/bad-sum" >/dev/null 2>&1; then fail "Bad checksum accepted."; fi
if [[ "$(id -u)" -eq 0 ]]; then
  bash "$BUILDER" "$L" >/dev/null || fail "Valid IANA-etc install failed."
  [[ -f "$L/tools/.glitchcore-ch8-iana-etc-complete" ]] || fail "Install marker missing."
  cmp -s "$T/src/iana-etc-20260805/services" "$L/etc/services" || fail "services install differs."
  cmp -s "$T/src/iana-etc-20260805/protocols" "$L/etc/protocols" || fail "protocols install differs."
  grep -Fq "Status: IANA-etc 20260805 installed and verified" "$L/CHAPTER-8-BUILD-INFO.txt" || fail "Build info missing status."
else
  echo "Root install test skipped (run this test under sudo for full coverage)." >&2
fi
echo "Chapter 8.4 IANA-etc preflight tests: OK"
