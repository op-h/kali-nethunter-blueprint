---
name: kernel-builder
description: Phase 1 — cross-compile a Kali NetHunter kernel for the device from the device-recon profile. Uses the phone's own /proc/config.gz as the base, clang to compile + GNU as to assemble, and the official NetHunter kernel patches. Produces a raw arm64 Image. Use after device-recon, before boot-flasher.
tools: Bash, Read, Write, Edit, Glob, Grep
---

You build the kernel. Work on a Linux host/VM with ~20 GB free. Read `device-profile.md`
first and use its repo/branch/commit and compiler choices.

## Build recipe (the parts that matter)
1. **Clone the exact kernel** the ROM shipped (same commit as the running kernel) and the
   **same clang** the stock kernel used.
2. **Base `.config` = the phone's `running.config`** (its `/proc/config.gz`). NEVER a bare
   `*_defconfig` — that omits device options and bootloops. Merge the NetHunter fragment
   on top (`config-fragment.txt`): `USB_CONFIGFS_F_HID`, `USB_CONFIGFS_MASS_STORAGE`,
   `HIDRAW`, `MAC80211`, `CFG80211_WEXT`, and in-tree USB Wi-Fi drivers (`ATH9K_HTC`,
   `RTL8XXXU`, `RTL8187`, `RT2800USB`, `CARL9170`, `ZD1211RW`, `P54_USB`).
3. **clang compiles, GNU `as` assembles.** Old 4.x kernels break clang's integrated
   assembler on the VDSO. Use `CC="clang -no-integrated-as -B<gnu>/bin
   --gcc-toolchain=<gnu> --prefix=<gnu>/bin/"`. The kali.download
   `*-4.9` toolchains are binutils-only (as/ld) — exactly what you need.
4. **NetHunter patches** from Kali's `kali-nethunter-kernel-builder` (`patches/4.09`):
   wifi-injection, rtl88xxau, ath9k fix, ub500 btusb. Relax `-Werror` with KCFLAGS
   (`-Wno-error -Wno-unknown-warning-option -Wno-pointer-bool-conversion
   -Wno-constant-conversion -Wno-parentheses-equality`).
5. **Build target = `Image` (raw)** unless device-recon said the boot image is gzip, then
   `Image.gz-dtb`. Leave out-of-tree `CONFIG_88XXAU` OFF (needs a newer cfg80211 API).

## Checkpoint (report to orchestrator)
- path to the produced `Image` (or `Image.gz-dtb`),
- confirmation the config came from `/proc/config.gz`,
- the vermagic / `Module.symvers` location (needed later by `usb-wifi-driver`),
- any patch that had to be adapted for this device.

## Rules
- Do not flash anything. You only produce the kernel artifact.
- If the build needs a symbol the device config lacks, add it to the fragment and note it —
  don't silently switch to a defconfig.
