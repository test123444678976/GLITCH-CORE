#!/usr/bin/env bash
set -Eeuo pipefail

ARCHIVE="ncurses-6.6.tar.gz"
SOURCES="${1:?Usage: ensure-ncurses-source.sh SOURCES_DIR}"
DEFAULT_MIRRORS=$'https://ftp.task.gda.pl/pub/gnu/ncurses/ncurses-6.6.tar.gz\nhttps://mirrors.hust.edu.cn/gnu/ncurses/ncurses-6.6.tar.gz'
MIRROR_LIST="${NCURSES_MIRROR_URLS:-$DEFAULT_MIRRORS}"

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$SOURCES" && ! -L "$SOURCES" ]] || fail "Invalid LFS sources directory: $SOURCES"
[[ -s "$SOURCES/md5sums" && ! -L "$SOURCES/md5sums" ]] || fail "Official LFS checksum manifest is missing."
[[ ! -L "$SOURCES/$ARCHIVE" ]] || fail "Refusing symlinked archive: $SOURCES/$ARCHIVE"

mapfile -t checksums < <(awk -v archive="$ARCHIVE" '$2 == archive { print $1 }' "$SOURCES/md5sums")
[[ "${#checksums[@]}" -eq 1 ]] || fail "Expected exactly one official checksum for $ARCHIVE."
expected="${checksums[0]}"
[[ "$expected" =~ ^[[:xdigit:]]{32}$ ]] || fail "Invalid official MD5 for $ARCHIVE."

if [[ -f "$SOURCES/$ARCHIVE" ]] &&
   (cd "$SOURCES" && printf '%s  %s\n' "$expected" "$ARCHIVE" | md5sum --check --status -); then
  echo "==> Verified existing $ARCHIVE against the official LFS manifest"
  exit 0
fi

echo "==> Fetching ncurses 6.6 from an alternate GNU archive mirror"
readarray -t mirrors <<< "$MIRROR_LIST"
tmp_file=""
cleanup() { [[ -z "$tmp_file" ]] || rm -f -- "$tmp_file"; }
trap cleanup EXIT

for url in "${mirrors[@]}"; do
  [[ -n "$url" ]] || continue
  if [[ "$url" != https://* ]]; then
    echo "WARNING: ignoring non-HTTPS ncurses mirror: $url" >&2
    continue
  fi

  tmp_file="$(mktemp "$SOURCES/.${ARCHIVE}.XXXXXX")"
  if wget --https-only --tries=2 --timeout=30 --waitretry=2 \
      --output-document="$tmp_file" "$url"; then
    if (cd "$SOURCES" && printf '%s  %s\n' "$expected" "$(basename "$tmp_file")" | md5sum --check -); then
      mv -f -- "$tmp_file" "$SOURCES/$ARCHIVE"
      tmp_file=""
      echo "==> Installed checksum-verified $ARCHIVE from alternate mirror"
      exit 0
    fi
    echo "WARNING: ncurses mirror supplied an archive with the wrong official MD5: $url" >&2
  else
    echo "WARNING: ncurses mirror download failed: $url" >&2
  fi
  rm -f -- "$tmp_file"
  tmp_file=""
done

fail "Could not obtain a checksum-valid $ARCHIVE from the configured HTTPS mirrors."
