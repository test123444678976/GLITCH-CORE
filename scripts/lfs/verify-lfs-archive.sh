#!/usr/bin/env bash
set -Eeuo pipefail

# Verify one official LFS source archive against the downloaded LFS md5sums
# manifest. This is an integrity check, not a substitute for HTTPS transport.
SOURCES_INPUT="${1:-}"
ARCHIVE="${2:-}"
fail(){ echo "ERROR: $*" >&2; exit 1; }

[[ -n "$SOURCES_INPUT" && -n "$ARCHIVE" ]] || fail "Usage: $0 /path/to/lfs/sources archive-name"
[[ "$SOURCES_INPUT" == /* && -d "$SOURCES_INPUT" ]] || fail "Sources path must be an existing absolute directory."
[[ "$ARCHIVE" == "$(basename "$ARCHIVE")" && "$ARCHIVE" != "." && "$ARCHIVE" != ".." ]] || fail "Archive must be a plain filename."
SOURCES="$(realpath -e "$SOURCES_INPUT")"
[[ "$SOURCES" != "/" ]] || fail "Refusing to use the host root as a source directory."

MANIFEST="$SOURCES/md5sums"
FILE="$SOURCES/$ARCHIVE"
[[ -f "$MANIFEST" && ! -L "$MANIFEST" && -s "$MANIFEST" ]] || fail "Official LFS md5sums manifest is missing or unsafe."
[[ -f "$FILE" && ! -L "$FILE" && -s "$FILE" ]] || fail "Source archive is missing, empty or a symlink: $FILE"

expected="$(awk -v name="$ARCHIVE" '
  NF == 2 {
    filename=$2
    sub(/^\*/, "", filename)
    if (filename == name) { print $1; count++ }
  }
  END { if (count != 1) exit 1 }
' "$MANIFEST")" || fail "Expected exactly one checksum entry for $ARCHIVE."
[[ "$expected" =~ ^[[:xdigit:]]{32}$ ]] || fail "Invalid MD5 value in official manifest for $ARCHIVE."
printf '%s  %s\n' "$expected" "$FILE" | md5sum --check --status || fail "LFS source archive checksum mismatch: $ARCHIVE"

echo "Verified official LFS source archive: $ARCHIVE"
