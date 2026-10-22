<div align="center">

<img src="docs/images/app-icon.png" width="96" height="96" alt="Kali NetHunter launcher icon"/>

# Kali NetHunter — Kernel + Terminal Blueprint

**A complete, reproducible recipe for bringing full Kali NetHunter to a rooted Android phone:**
build a custom NetHunter kernel, flash it without a bootloop, enhance the Kali shell,
and ship a one-tap launcher app — all documented end to end.

Demonstrated on a **Samsung Galaxy Note 9 (SM-N960F · crownlte · Exynos 9810)** running
**LineageOS 20 / Android 13** with **Magisk**, but written as a blueprint for **any rooted device**.

![platform](https://img.shields.io/badge/platform-Android%2013-3DDC84)
![kernel](https://img.shields.io/badge/kernel-Linux%204.9-E6EDF3)
![root](https://img.shields.io/badge/root-Magisk-D81A3F)
![nethunter](https://img.shields.io/badge/Kali-NetHunter-1793D1)
![license](https://img.shields.io/badge/license-MIT-blue)

</div>

> [!WARNING]
> **Authorized use only.** This project is for security research, education, and testing on
> devices and networks **you own or are explicitly permitted to test**. Flashing a kernel can
> brick a device — always keep the stock backup (`boot/recovery.sh` restores it). You accept all risk.

---

## What you get

| | |
|---|---|
| 🧩 **Custom NetHunter kernel** | USB HID (BadUSB), USB mass-storage gadget, `mac80211` + Wi-Fi injection, external USB Wi-Fi adapter drivers (Atheros `ath9k_htc`, Realtek `rtl8xxxu`/`rtl8187`, Ralink `rt2800usb`, `carl9170`, `zd1211rw`). |
| 🐚 **Enhanced Kali shell** | `zsh` with the authentic Kali two-line prompt, fish-style autosuggestions, syntax highlighting, tab-completion, and an interactive `nh` / `tools` launcher for the installed toolkit. |
| 📱 **One-tap launcher app** | A signed APK (`com.oph.nethunter`) with its own icon that opens the NetHunter Terminal straight into the enhanced Kali shell. Built **without Gradle**. |
| 🛟 **Bootloop-proof flashing** | Auto-detects the stock kernel format (raw vs gzip) and keeps the Magisk ramdisk + device tree, plus a tested stock-restore recovery path. |

<div align="center">
<img src="docs/images/01-enhanced-shell.png" width="30%" alt="Enhanced Kali shell"/>
&nbsp;
<img src="docs/images/02-launcher-opens-kali.png" width="30%" alt="Launcher opens Kali"/>
&nbsp;
<img src="docs/images/03-tools-menu.png" width="30%" alt="Tool menu"/>
<br/>
<sub>Enhanced zsh prompt · one-tap launcher · the <code>tools</code> menu</sub>
</div>

---

## Architecture

<div align="center"><img src="docs/diagrams/architecture.svg" width="92%" alt="Architecture"/></div>

The only piece that must be **compiled** is the kernel. Everything above it (Magisk, the Kali
chroot, NeoTerm) already exists — the kernel is what unlocks HID attacks and Wi-Fi monitor/injection.

---

## Prerequisites

- A **rooted** phone (Magisk) with Kali NetHunter installed (the app + chroot + NetHunter Terminal).
- A Linux build host (or VM) with ~20 GB free, `adb`, and internet.
- `magiskboot` on the phone (ships with Magisk at `/data/adb/magisk/magiskboot`).
- Your device's kernel source + the Google clang your stock kernel was built with.

> There is **no prebuilt NetHunter kernel** for crownlte on LineageOS 20 — that is exactly why
> this blueprint compiles one. For other devices, swap the kernel repo/branch in `kernel/build.sh`.

---

## Step by step

### 1 · Back up and pull the real config

```bash
# keep a known-good backup FIRST — this is your lifeline
adb shell su -c 'dd if=/dev/block/by-name/BOOT of=/sdcard/boot-stock.img'
adb pull /sdcard/boot-stock.img ./boot-stock.img
# the config that actually boots your phone (NOT a defconfig — that can bootloop)
adb shell su -c 'zcat /proc/config.gz' > running.config
```

### 2 · Build the kernel

```bash
RUNNING_CONFIG=$PWD/running.config ./kernel/build.sh
```

Key choices baked into [`kernel/build.sh`](kernel/build.sh):

- **Base `.config` = the phone's own `/proc/config.gz`.** A plain `*_defconfig` build is missing
  device-critical options and bootloops. This was the difference between a 14 MB dud and a working kernel.
- **clang compiles, GNU `as` assembles.** Old kernels break clang's integrated assembler on the VDSO
  (`too many positional arguments`). `-no-integrated-as` with the Google binutils fixes it.
- **Relax `-Werror`** for the out-of-tree Wi-Fi drivers under newer clang.
- NetHunter patches come from Kali's official
  [`kali-nethunter-kernel-builder`](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder)
  (`patches/4.09`) via [`kernel/apply-patches.sh`](kernel/apply-patches.sh); extra `CONFIG` symbols live in
  [`kernel/config-fragment.txt`](kernel/config-fragment.txt).

### 3 & 4 · Repack and flash — *mind the format*

<div align="center"><img src="docs/diagrams/boot-format.svg" width="92%" alt="Boot format gotcha"/></div>

This is the trap that bootloops most people. The crownlte boot image stores the kernel as a **raw,
uncompressed arm64 `Image`** (`'ARMd'` magic at `0x38`) with the device tree in a separate **DTBH**
section — the bootloader does **not** gunzip. Flash a `Image.gz-dtb` there and it jumps into gzip
bytes and dies on the Samsung logo.

[`boot/repack-and-flash.sh`](boot/repack-and-flash.sh) auto-detects the format, swaps **only** the
kernel (keeping the Magisk ramdisk so root survives and the DTBH so hardware matches), then `dd`s it:

```bash
adb push out/arch/arm64/boot/Image /sdcard/nh-backup/Image
adb shell su -c 'sh /sdcard/.../repack-and-flash.sh'
adb reboot
```

### Recovery (if it bootloops)

Nothing is lost — the kernel only lives in the boot partition. From stock recovery:

```bash
./boot/recovery.sh        # pushes boot-stock.img and dd's it back
```

Samsung combos (USB plugged in): force-off = **Vol Down + Power** (~10 s); recovery = **Vol Up + Bixby + Power**.

---

## 6 · Enhance the Kali shell

```bash
adb push shell/setup-kali-shell.sh /sdcard/ && \
adb shell su -c 'sh /path/bootkali custom_cmd bash /root/setup-kali-shell.sh'
```

Installs `zsh` + autosuggestions + syntax-highlighting, writes the Kali-style prompt, and adds:

- **`nh`** — an interactive, categorized launcher (recon / scanning / exploitation / wireless / web / passwords) that pre-fills ready-to-run commands.
- **`tools`** — a color-coded inventory of the installed toolkit.

[`nhterm-fix/fix-nhterm-kali.sh`](nhterm-fix/fix-nhterm-kali.sh) makes the NetHunter Terminal's "Kali Shell"
session drop straight into this shell (regeneration-proof — it fixes the chroot path + `su` resolution
without editing NeoTerm's auto-regenerated files).

---

## 7 · The launcher app

A minimal, dependency-free Activity that opens `com.offsec.nhterm`'s `NeoTermActivity`. Source is in
[`terminal-app/`](terminal-app/); build + sign with **no Gradle** using only the Android SDK build-tools:

```powershell
# Windows / PowerShell — edit the SDK paths at the top first
./terminal-app/build-apk.ps1      # aapt2 → javac → d8 → zipalign → apksigner
adb install -r terminal-app/KaliNetHunter.apk
```

A prebuilt, signed [`KaliNetHunter.apk`](terminal-app/KaliNetHunter.apk) is included.

---

## Pipeline at a glance

<div align="center"><img src="docs/diagrams/pipeline.svg" width="92%" alt="Pipeline"/></div>

---

## Repository layout

```
kernel/        build.sh · apply-patches.sh · config-fragment.txt
boot/          repack-and-flash.sh · recovery.sh
shell/         setup-kali-shell.sh · nhlaunch.sh
nhterm-fix/    fix-nhterm-kali.sh
terminal-app/  AndroidManifest.xml · src/ · res/ · build-apk.ps1 · KaliNetHunter.apk
docs/          images/ (screenshots) · diagrams/ (SVG)
```

## Notes for other devices

- Swap `KERNEL_REPO` / `KERNEL_BRANCH` / `DEVICE_DEFCONFIG` in `kernel/build.sh`.
- Always base the config on that phone's `/proc/config.gz`.
- Check your boot image's kernel format before flashing (`magiskboot unpack`, then inspect `0x38`).
- The internal Wi-Fi of most phones (Broadcom, etc.) still can't do monitor mode without `nexmon`;
  external USB adapters (e.g. Atheros **AR9271**) work out of the box with this kernel.

---

<div align="center">

Built by **OPH** · [github.com/op-h](https://github.com/op-h)

Released under the [MIT License](LICENSE).

</div>
