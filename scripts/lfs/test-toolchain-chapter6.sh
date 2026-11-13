#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/lfs/build-toolchain-chapter6.sh"
LOCK="$ROOT/config/lfs-toolchain.lock"
fail(){ echo "ERROR: $*" >&2; exit 1; }

bash -n "$SCRIPT" || fail "Chapter 6 build script has invalid Bash syntax."
test -s "$LOCK" || fail "Pinned LFS source contract is missing."

for required in \
  'm4 1.4.21 m4-1.4.21.tar.xz' \
  'ncurses-6.6.tar.gz' \
  'bash 5.3 bash-5.3.tar.gz' \
  'coreutils 9.11 coreutils-9.11.tar.xz' \
  'diffutils 3.12 diffutils-3.12.tar.xz' \
  'file-5.48.tar.gz' \
  'findutils 4.11.0 findutils-4.11.0.tar.xz' \
  'gawk-5.4.1.tar.xz' \
  'grep 3.12 grep-3.12.tar.xz' \
  'gzip 1.14 gzip-1.14.tar.xz' \
  'make 4.4.1 make-4.4.1.tar.gz' \
  'patch 2.8 patch-2.8.tar.xz' \
  'sed 4.10 sed-4.10.tar.xz' \
  'tar 1.35 tar-1.35.tar.xz' \
  'xz 5.8.3 xz-5.8.3.tar.xz' \
  'mpc-1.4.1.tar.xz' \
  'Binutils Pass 2' \
  'GCC Pass 2' \
  '.glitchcore-binutils-pass2-complete' \
  '.glitchcore-gcc-pass2-complete' \
  'target_configargs=gcc_cv_target_thread_file=posix' \
  'printing config.log diagnostics' \
  'tail -n 160 config.log'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "Chapter 6 recipe or checkpoint is missing: $required"
done

for required in \
  'LFS_BOOK=13.1-systemd' \
  'BINUTILS=2.47' \
  'GCC=16.2.0' \
  'MPC=1.4.1' \
  'CHAPTER6_PACKAGES=m4-1.4.21,ncurses-6.6,bash-5.3,coreutils-9.11,diffutils-3.12,file-5.48,findutils-4.11.0,gawk-5.4.1,grep-3.12,gzip-1.14,make-4.4.1,patch-2.8,sed-4.10,tar-1.35,xz-5.8.3' \
  'CHAPTER6_STAGES=temporary-tools,binutils-pass2,gcc-pass2'; do
  grep -Fxq -- "$required" "$LOCK" || fail "Pinned Chapter 6 contract mismatch: $required"
done

# The script must fail closed if invoked without the Chapter 5 checkpoint.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/lfs/sources" "$tmp/lfs/tools"
if LFS="$tmp/lfs" LFS_TGT=x86_64-lfs-linux-gnu bash "$SCRIPT" >/dev/null 2>&1; then
  fail "Chapter 6 build accepted a workspace without Chapter 5 markers."
fi

WORKFLOW="$ROOT/.github/workflows/lfs-toolchain.yml"

# Chapter 5/6 use dot-prefixed completion markers. Keep them inside the
# cross-job checkpoints; upload-artifact excludes hidden files by default.
awk '
/^      - name:/ { chapter5 = 0; chapter6 = 0 }
/^      - name: Upload Chapter 5 cross-toolchain checkpoint/ { chapter5 = 1 }
/^      - name: Upload Chapter 6 temporary-tools checkpoint/ { chapter6 = 1 }
chapter5 && /include-hidden-files: true/ { chapter5_hidden = 1 }
chapter6 && /include-hidden-files: true/ { chapter6_hidden = 1 }
END { if (!chapter5_hidden || !chapter6_hidden) exit 1 }
' "$WORKFLOW" || fail "LFS toolchain checkpoints must preserve hidden completion markers."

grep -Fq 'mv -f "$LFS/usr/bin/chroot" "$LFS/usr/sbin/chroot"' "$SCRIPT" || fail "Coreutils chroot must be moved to /usr/sbin."
grep -Fq 'test -x "$LFS/usr/sbin/chroot"' "$SCRIPT" || fail "Chapter 6 must verify chroot at /usr/sbin/chroot."
if grep -Fq 'test -x "$LFS/usr/bin/chroot"' "$SCRIPT"; then
  fail "Chapter 6 still checks the pre-move /usr/bin/chroot path."
fi

awk '
/sudo apt-get install -y/ {
  slash = sprintf("%c", 92)
  trailing = 0
  for (i = length($0); i > 0 && substr($0, i, 1) == slash; i--) trailing++
  if (trailing != 1) exit 1
  count++
}
END { if (count != 3) exit 1 }
' "$WORKFLOW" || fail "LFS workflow install commands must use one line-continuation backslash."

echo "LFS Chapter 6 temporary-tools regression tests: OK"
