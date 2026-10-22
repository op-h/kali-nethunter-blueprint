#!/usr/bin/env bash
# =============================================================================
# NetHunter kernel build  -  blueprint (op-h / github.com/op-h)
# Demonstrated on: Samsung Galaxy Note 9 (SM-N960F, crownlte, Exynos9810),
#                  LineageOS 20 / Android 13, kernel 4.9.
#
# The golden rules that make this reproducible on ANY device:
#   1. Base your .config on the phone's OWN /proc/config.gz  (NOT a defconfig).
#   2. Compile with the SAME clang the stock kernel used, but ASSEMBLE with
#      GNU `as` (old kernels break clang's integrated assembler).
#   3. Know your boot image's kernel format BEFORE flashing (see boot/).
#
# Edit the CONFIG section for your device, then run inside a Linux box with
# ~20 GB free. Produces: out/arch/arm64/boot/Image   (raw, uncompressed)
# =============================================================================
set -euo pipefail

# ----------------------------- CONFIG (edit me) ------------------------------
WORK="${WORK:-$HOME/nhk}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/LineageOS/android_kernel_samsung_exynos9810}"
KERNEL_BRANCH="${KERNEL_BRANCH:-lineage-20}"
DEVICE_DEFCONFIG="${DEVICE_DEFCONFIG:-exynos9810-crownlte_defconfig}"  # fallback only
RUNNING_CONFIG="${RUNNING_CONFIG:-$WORK/running.config}"  # pull from phone: adb shell su -c 'zcat /proc/config.gz'
# Google prebuilt clang used by LineageOS 20 (match your stock kernel's clang!)
CLANG_URL="${CLANG_URL:-https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android12-release/clang-r416183b.tar.gz}"
# Google binutils (as/ld) 4.9 from the Kali mirror
GCC64_URL="${GCC64_URL:-https://kali.download/nethunter-images/toolchains/google_aarch64-4.9.tar.xz}"
GCC32_URL="${GCC32_URL:-https://kali.download/nethunter-images/toolchains/google_armhf-4.9.tar.xz}"
# -----------------------------------------------------------------------------

mkdir -p "$WORK"; cd "$WORK"

echo "[*] deps"
sudo apt-get update -qq
sudo apt-get install -y -qq git bc bison flex libssl-dev libelf-dev make cpio kmod \
    python3 ccache binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu lz4 xz-utils unzip curl

echo "[*] kernel source"
[ -d kernel ] || git clone --depth 1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel

echo "[*] toolchains"
mkdir -p clang tc/aarch64-4.9 tc/armhf-4.9
[ -x clang/bin/clang ] || { curl -L "$CLANG_URL" -o clang.tgz; tar xzf clang.tgz -C clang; rm clang.tgz; }
ls tc/aarch64-4.9/bin/*as >/dev/null 2>&1 || { curl -L "$GCC64_URL" -o g64.txz; tar --strip-components=1 -xf g64.txz -C tc/aarch64-4.9; rm g64.txz; }
ls tc/armhf-4.9/bin/*as   >/dev/null 2>&1 || { curl -L "$GCC32_URL" -o g32.txz; tar --strip-components=1 -xf g32.txz -C tc/armhf-4.9; rm g32.txz; }

export PATH="$WORK/clang/bin:$WORK/tc/aarch64-4.9/bin:$WORK/tc/armhf-4.9/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu-
GA="$WORK/tc/aarch64-4.9"
# clang compiles, GNU `as` assembles (fixes vdso macro errors on old kernels)
CCX="clang -no-integrated-as -B$GA/bin --gcc-toolchain=$GA --prefix=$GA/bin/ -Qunused-arguments -Wno-unused-command-line-argument -Wno-unknown-warning-option"
# relax warnings-as-errors for old drivers under new clang
KC="-Wno-error -Wno-unknown-warning-option -Wno-pointer-bool-conversion -Wno-constant-conversion -Wno-parentheses-equality -Wno-tautological-compare -Wno-unused-function"

cd kernel

echo "[*] base config"
if [ -f "$RUNNING_CONFIG" ]; then
    echo "    using the phone's own running config (recommended)"
    mkdir -p out; cp "$RUNNING_CONFIG" out/.config
else
    echo "    WARNING: no running.config found, falling back to $DEVICE_DEFCONFIG"
    echo "    (a defconfig build may be missing device options and can bootloop!)"
    make O=out ARCH=arm64 CC="$CCX" "$DEVICE_DEFCONFIG"
fi

echo "[*] apply NetHunter patches + config fragment"
bash "$WORK/../apply-patches.sh" || true   # see kernel/apply-patches.sh
while read -r opt; do
    [ -z "$opt" ] && continue
    case "$opt" in \#*) continue;; esac
    scripts/config --file out/.config --enable "$opt"
done < "${CONFIG_FRAGMENT:-$WORK/../config-fragment.txt}"
scripts/config --file out/.config --disable CONFIG_88XXAU   # needs 4.12 API on this tree

make O=out ARCH=arm64 CC="$CCX" olddefconfig

echo "[*] build"
make -j"$(nproc)" O=out ARCH=arm64 CC="$CCX" KCFLAGS="$KC" Image.gz-dtb

echo "[+] done:"
ls -la out/arch/arm64/boot/Image out/arch/arm64/boot/Image.gz-dtb
echo "[!] Use the RAW 'Image' (not Image.gz-dtb) if your stock boot stores the"
echo "    kernel uncompressed. Check with: boot/README and magiskboot unpack."
