#!/usr/bin/env bash
set -Eeuo pipefail
CHECK_ONLY=0
if [[ "${1:-}" == "--check-only" ]]; then CHECK_ONLY=1; shift; fi
[[ $# -eq 1 ]] || { echo "Usage: $0 [--check-only] /absolute/path/to/LFS" >&2; exit 2; }
INPUT="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE=iana-etc-20260805.tar.gz
MARKER=.glitchcore-ch8-iana-etc-complete
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$INPUT" == /* && -d "$INPUT" && ! -L "$INPUT" ]] || fail "Unsafe LFS root."
LFS="$(realpath -e "$INPUT")"
[[ "$LFS" != / ]] || fail "Refusing host root."
for p in sources tools etc; do [[ -d "$LFS/$p" && ! -L "$LFS/$p" ]] || fail "Missing or unsafe directory: $p"; done
[[ -f "$LFS/tools/.glitchcore-chapter7-temporary-tools-complete" ]] || fail "Chapter 7 checkpoint is incomplete."
[[ -f "$LFS/tools/.glitchcore-ch8-man-pages-complete" ]] || fail "Man-pages checkpoint is missing."
bash "$ROOT/scripts/lfs/verify-lfs-archive.sh" "$LFS/sources" "$ARCHIVE" >/dev/null
listing="$(mktemp)"
trap 'rm -f "$listing"' EXIT
if ! tar -tzf "$LFS/sources/$ARCHIVE" >"$listing"; then fail "Cannot read IANA-etc source archive."; fi
for f in services protocols; do
  grep -Fx "iana-etc-20260805/$f" "$listing" >/dev/null || fail "IANA-etc archive is missing $f."
done
if (( CHECK_ONLY )); then echo "Chapter 8.4 IANA-etc preflight: OK"; exit 0; fi
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && "$(id -u)" -eq 0 ]] || fail "Install requires root on Linux x86_64."
[[ ! -e "$LFS/tools/$MARKER" ]] || { echo "IANA-etc already installed."; exit 0; }
tmp="$(mktemp -d "$LFS/sources/.iana-etc-install.XXXXXX")"
cleanup(){ rm -rf "$tmp"; }
trap cleanup EXIT
tar -xzf "$LFS/sources/$ARCHIVE" -C "$tmp"
SRC="$tmp/iana-etc-20260805"
for f in services protocols; do [[ -s "$SRC/$f" && ! -L "$SRC/$f" ]] || fail "Invalid extracted source file: $f"; done
grep -Eq '(^|[[:space:]])tcp([[:space:]]|$)' "$SRC/services" || fail "services file lacks TCP entries."
grep -Eq '(^|[[:space:]])ip([[:space:]]|$)' "$SRC/protocols" || fail "protocols file lacks IP entries."
install -o root -g root -m 0644 "$SRC/services" "$LFS/etc/services.new"
install -o root -g root -m 0644 "$SRC/protocols" "$LFS/etc/protocols.new"
mv -f "$LFS/etc/services.new" "$LFS/etc/services"
mv -f "$LFS/etc/protocols.new" "$LFS/etc/protocols"
cmp -s "$SRC/services" "$LFS/etc/services" || fail "Installed services differs from source."
cmp -s "$SRC/protocols" "$LFS/etc/protocols" || fail "Installed protocols differs from source."
{
 echo "GLITCH//CORE LFS 13.1-systemd Chapter 8.4 — IANA-etc 20260805"
 echo "Target: x86_64-lfs-linux-gnu"
 echo "Source SHA256: $(sha256sum "$LFS/sources/$ARCHIVE" | awk '{print $1}')"
 echo "Installed: /etc/services and /etc/protocols"
 echo "Status: IANA-etc 20260805 installed and verified"
} >> "$LFS/CHAPTER-8-BUILD-INFO.txt"
touch "$LFS/tools/$MARKER"
echo "Chapter 8.4 IANA-etc 20260805: PASSED"
