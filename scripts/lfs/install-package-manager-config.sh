#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_INPUT="${1:-}"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ -n "$TARGET_INPUT" ]] || fail "Usage: $0 /absolute/path/to/LFS-rootfs"
[[ "$TARGET_INPUT" == /* && -d "$TARGET_INPUT" ]] || fail "Target must be an existing absolute directory."
TARGET="$(realpath -e "$TARGET_INPUT")"
[[ "$TARGET" != "/" ]] || fail "Refusing to modify host root."
[[ -d "$TARGET/etc" && -d "$TARGET/usr" ]] || fail "Target does not look like an LFS rootfs."

# Never follow target-internal symlinks while writing configuration. A target
# may be untrusted or partially assembled; an etc/var link could redirect
# writes outside the selected rootfs and into the build host.
for relative in \
  etc etc/apt etc/apt/sources.list.d etc/apt/trusted.gpg.d \
  var var/lib var/lib/dpkg var/lib/apt var/lib/apt/lists var/lib/apt/lists/partial \
  var/cache var/cache/apt var/cache/apt/archives var/cache/apt/archives/partial \
  etc/apt/apt.conf etc/apt/sources.list var/lib/dpkg/status; do
  [[ ! -L "$TARGET/$relative" ]] || fail "Refusing symlink in target configuration path: $relative"
done
for bin in usr/bin/dpkg usr/bin/dpkg-deb usr/bin/apt-get usr/bin/apt-cache; do
  [[ -x "$TARGET/$bin" ]] || fail "Required native target executable missing: $bin"
done
install -D -m 0644 "$ROOT/config/apt/apt.conf" "$TARGET/etc/apt/apt.conf"
install -D -m 0644 "$ROOT/config/apt/sources.list" "$TARGET/etc/apt/sources.list"
install -d -m 0755 "$TARGET/etc/apt/sources.list.d" "$TARGET/etc/apt/trusted.gpg.d" \
  "$TARGET/var/lib/dpkg" "$TARGET/var/lib/apt/lists/partial" \
  "$TARGET/var/cache/apt/archives/partial"
if [[ ! -e "$TARGET/var/lib/dpkg/status" ]]; then
  install -m 0644 /dev/null "$TARGET/var/lib/dpkg/status"
fi
echo "APT/dpkg configuration initialized in: $TARGET"
echo "No repository is enabled; install and verify the GLITCH//CORE archive key before adding a source."
echo "This configures the target only; it does not copy host binaries or claim package operations have passed."
