#!/usr/bin/env bash
# build-rtl88x2bu.sh — cross-compile the RTL8812BU (rtl88x2bu) driver as a
# LOADABLE kernel module for the custom NetHunter kernel, with the fix that
# makes it actually probe without rebooting the phone.
#
# WHY A MODULE (not in-tree): the RTL8812BU needs the out-of-tree rtl88x2bu
# driver, which won't build in-tree against this old 4.9 cfg80211 API. Building
# it as a .ko against the kernel's own out/ lets you insmod it with no reflash.
#
# THE CRITICAL FIX — -fno-stack-protector (in BOTH CC and KCFLAGS):
#   Without it, clang emits a USERSPACE stack-canary read
#       mrs x20, tpidr_el0 ; ldr x8,[x20,#40]
#   at rtw_drv_init+0x24. On probe the kernel dereferences tpidr_el0 (a
#   userspace register) -> "Accessing user space memory outside uaccess.h
#   routines" PAN fault -> instant reboot. Disabling the stack protector for
#   this module removes the canary read and it loads cleanly.
#
# Other keys:
#   - KSRC must point at the kernel's built out/ (command-line KSRC overrides the
#     Makefile's `:=` assignment).
#   - strip -mhard-float / -mfloat-abi=hard from the Makefile (invalid on arm64).
#   - keep CONFIG_PLATFORM_I386_PC=y so the needed cfg80211 defines are set.
#   - vermagic must match: build against the SAME kernel tree you flashed,
#     MODULE_SIG off, MODVERSIONS on, Module.symvers present.
#
# USAGE: edit the paths below for your build host, then run.
set -euo pipefail

# --- paths (edit me) --------------------------------------------------------
W="${W:-$HOME/nhk}"                  # workspace
DRV="${DRV:-$W/rtl88x2bu}"           # github.com/RinCat/RTL88x2BU-Linux-Driver
K="${K:-$W/kernel}"                  # kernel source; built output in $K/out
CLANG_BIN="${CLANG_BIN:-$W/clang/bin}"          # Google clang r416183b
GNU_AARCH64="${GNU_AARCH64:-$W/tc/aarch64-4.9}" # GNU binutils (as/ld) aarch64
GNU_ARMHF="${GNU_ARMHF:-$W/tc/armhf-4.9}"        # GNU binutils armhf
# ---------------------------------------------------------------------------

export PATH="$CLANG_BIN:$GNU_AARCH64/bin:$GNU_ARMHF/bin:$PATH"

# clang that compiles but hands assembly to GNU as, with the stack protector OFF
CCX="clang -fno-stack-protector -no-integrated-as \
  -B$GNU_AARCH64/bin --gcc-toolchain=$GNU_AARCH64 --prefix=$GNU_AARCH64/bin/ \
  -Qunused-arguments -Wno-unused-command-line-argument -Wno-unknown-warning-option"

cd "$DRV"

# strip arm64-invalid float flags the driver Makefile adds
sed -i 's/^\(\s*\)ccflags-y += -mhard-float/\1# removed for arm64/'   Makefile || true
sed -i 's/^\(\s*\)ccflags-y += -mfloat-abi=hard/\1# removed for arm64/' Makefile || true

# -fno-stack-protector here too (the actual fix); relax warnings for old driver + new clang
export KCFLAGS="-fno-stack-protector -Wno-error -Wno-unknown-warning-option \
  -Wno-implicit-function-declaration -Wno-pointer-bool-conversion \
  -Wno-parentheses-equality -Wno-tautological-compare -Wno-unused -Wno-constant-conversion"

make clean >/dev/null 2>&1 || true
echo "=== building rtl88x2bu.ko against $K/out ==="
make -j"$(nproc)" \
  KSRC="$K/out" ARCH=arm64 SUBARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-android- \
  CONFIG_PLATFORM_I386_PC=y \
  CC="$CCX" \
  modules

ko=$(ls -1 "$DRV"/*.ko 2>/dev/null | head -1)
[ -n "$ko" ] || { echo "BUILD FAILED: no .ko produced"; exit 1; }
echo
echo "[OK] built: $ko"
echo "     verify it has NO userspace canary read (should print nothing):"
echo "     aarch64-linux-android-objdump -d \"$ko\" | grep tpidr_el0"
echo "     next: wifi-adapter/install-magisk-module.sh \"$ko\""
