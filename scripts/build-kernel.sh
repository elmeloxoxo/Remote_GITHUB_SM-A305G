#!/usr/bin/env bash
# Builds on a remote Linux runner. Does not flash, publish a release, or access
# the phone. Failure logs are preserved. A successful build is not a panic fix.
set -euo pipefail

RECIPE_ROOT=$(pwd -P)
ARTIFACTS="$RECIPE_ROOT/artifacts"
mkdir -p "$ARTIFACTS"
exec > >(tee -a "$ARTIFACTS/build.log") 2>&1

case "${A30_REVISION:-original-241a585}" in
  original-241a585) KERNEL_REV=241a585e09e4a5d4c416b9a16c683cb4af6460e9 ;;
  posterior-55d8ab3) KERNEL_REV=55d8ab30547ef33dd3f900fec5f8f98f764b3352 ;;
  *) echo 'Revision no permitida'; exit 1 ;;
esac
KERNEL_REPO=https://github.com/Shaheddan/android_kernel_samsung_exynos7885.git
CLANG_REPO=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
CLANG_REV=70a12c4fe88940ab2b0e6d763492dffa2f07e15a
CLANG_DIR=clang-r547379

cat > "$ARTIFACTS/source-info.txt" <<EOF
EXPERIMENTAL - NOT A VALIDATED STABILITY FIX
Kernel repository: $KERNEL_REPO
Kernel revision: $KERNEL_REV
Compiler repository: $CLANG_REPO
Compiler revision: $CLANG_REV
Compiler directory: $CLANG_DIR
Compiler: AOSP Clang 20.0.0; original phone image declares Clang 21.0.0.
Configuration: copied from the original PixelOS boot, with explicit local version.
boot.img, DTB and DTBO on the phone are not modified by this workflow.
Do not flash Image directly as boot.img.
EOF

sha256sum config/pixel-original.config | tee "$ARTIFACTS/input-config.sha256"
sha256sum -c config/pixel-original.config.sha256
grep -qx 'CONFIG_ARM64=y' config/pixel-original.config
grep -qx 'CONFIG_KSU=y' config/pixel-original.config
grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' config/pixel-original.config

SRC="$RECIPE_ROOT/kernel-source"
TOOLCHAIN="$RECIPE_ROOT/toolchain"
OUT="$RECIPE_ROOT/kernel-output"
for directory in "$SRC" "$TOOLCHAIN" "$OUT"; do
  [ ! -e "$directory" ] || { echo "Directory already exists: $directory"; exit 1; }
done

git init "$SRC"
git -C "$SRC" remote add origin "$KERNEL_REPO"
git -C "$SRC" fetch --depth=1 origin "$KERNEL_REV"
git -C "$SRC" checkout --detach FETCH_HEAD
[ "$(git -C "$SRC" rev-parse HEAD)" = "$KERNEL_REV" ]
# KernelSU-Next is vendored in this revision. No remote install script is run.
[ -d "$SRC/KernelSU-Next/kernel" ]

git clone --depth=1 --filter=blob:none --sparse "$CLANG_REPO" "$TOOLCHAIN"
git -C "$TOOLCHAIN" fetch --depth=1 origin "$CLANG_REV"
git -C "$TOOLCHAIN" checkout --detach FETCH_HEAD
git -C "$TOOLCHAIN" sparse-checkout set "$CLANG_DIR"
[ "$(git -C "$TOOLCHAIN" rev-parse HEAD)" = "$CLANG_REV" ]
export PATH="$TOOLCHAIN/$CLANG_DIR/bin:$PATH"
clang --version | tee "$ARTIFACTS/compiler-version.txt"
clang --version | head -1 | grep -q '20.0.0'

mkdir "$OUT"
cp config/pixel-original.config "$OUT/.config"
export KBUILD_BUILD_USER=a30-builder
export KBUILD_BUILD_HOST=github-actions
export KBUILD_BUILD_TIMESTAMP='Thu Nov 12 00:00:00 UTC 2026'

MAKE_ARGS=(
  -C "$SRC" O="$OUT" ARCH=arm64
  LLVM=1 LLVM_IAS=1
  CC=clang HOSTCC=clang HOSTCXX=clang++
  LD=ld.lld AR=llvm-ar NM=llvm-nm
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  CLANG_TRIPLE=aarch64-linux-gnu-
  LOCALVERSION="-A30-experimental-${KERNEL_REV:0:10}"
)

make "${MAKE_ARGS[@]}" olddefconfig
cp "$OUT/.config" "$ARTIFACTS/kernel.config"
diff -u config/pixel-original.config "$OUT/.config" > "$ARTIFACTS/config-diff.txt" || true
grep -qx 'CONFIG_KSU=y' "$OUT/.config"
grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' "$OUT/.config"
make "${MAKE_ARGS[@]}" -j"$(nproc)" Image

[ -s "$OUT/arch/arm64/boot/Image" ]
[ -s "$OUT/vmlinux" ]
cp "$OUT/arch/arm64/boot/Image" "$ARTIFACTS/Image"
cp "$OUT/vmlinux" "$ARTIFACTS/vmlinux"
cp "$OUT/System.map" "$ARTIFACTS/System.map"
python3 - "$ARTIFACTS/Image" <<'PY'
from pathlib import Path
import struct, sys
p = Path(sys.argv[1]); b = p.read_bytes()
assert b[56:60] == b'ARM\x64', 'Not a valid ARM64 Linux Image header'
declared = struct.unpack_from('<Q', b, 16)[0]
# ARM64 image_size includes memory such as BSS absent from the file itself.
assert 0 < len(b) <= declared <= 512 * 1024 * 1024, (declared, len(b))
print('Validated ARM64 Image header:', len(b), 'bytes; declared:', declared)
PY
(
  cd "$ARTIFACTS"
  sha256sum Image vmlinux System.map kernel.config > SHA256SUMS.txt
)
echo 'Compilation complete. Artifact is experimental and has not been boot-tested.'
