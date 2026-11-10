#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/config/package-manager.txt"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ -s "$MANIFEST" ]] || fail "Package-manager manifest is missing or empty."

declare -A seen=()
groups=0
entries=0
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | xargs)"
  [[ -z "$line" ]] && continue

  if [[ "$line" =~ ^\[[a-z0-9-]+\]$ ]]; then
    ((groups += 1))
    continue
  fi

  if [[ "$line" == -* ]]; then
    continue
  fi

  [[ "$line" =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$|^[a-zA-Z0-9-]+=[a-zA-Z0-9 /+-]+$ ]] ||
    fail "Invalid package-manager manifest entry: $raw"

  [[ -z "${seen[$line]+x}" ]] || fail "Duplicate entry: $line"
  seen["$line"]=1
  ((entries += 1))
done < "$MANIFEST"

(( groups >= 5 )) || fail "Expected package format, dependencies, tools, metadata and policy sections."
for required in dpkg apt curl gnutls gcrypt lz4 lzma zstd bz2 xxhash seccomp systemd; do
  [[ -n "${seen[$required]+x}" ]] || fail "Missing required package-manager target: $required"
done
for required in Packages Release InRelease Release.gpg; do
  [[ -n "${seen[$required]+x}" ]] || fail "Missing repository metadata target: $required"
done
for required in 'architecture=amd64' 'component=core' 'suite=stable' 'origin=GLITCH//CORE'; do
  [[ -n "${seen[$required]+x}" ]] || fail "Missing repository policy: $required"
done

grep -Fq 'without using Debian' "$MANIFEST" ||
  fail "Manifest must explicitly preserve the independent LFS base."
grep -Fq 'Do NOT copy Debian/Ubuntu binaries' "$MANIFEST" ||
  fail "Manifest is missing the no-foreign-binaries guard."

echo "GLITCH//CORE package-manager plan: OK"
echo "Sections: $groups | Entries: $entries"
echo "APT/dpkg are specified as native LFS source builds; they are NOT installed yet."
