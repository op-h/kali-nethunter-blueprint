#!/usr/bin/env bash
# Restore the stock boot image from a bootloop. Run from your PC with the phone
# in its stock recovery (LineageOS recovery / TWRP) exposing an adb shell.
#
# Samsung key combos (keep USB plugged in):
#   force off : hold Volume Down + Power ~10s
#   recovery  : hold Volume Up + Bixby + Power
#   download  : hold Volume Down + Bixby + Power   (for Odin/Heimdall instead)
# In LineageOS recovery, leave "Apply update from ADB" (sideload) and return to
# the main menu so `adb shell` works; approve the USB debugging prompt.
set -e
ADB="${ADB:-adb}"
STOCK="${STOCK:-./boot-stock.img}"          # your known-good backup
BOOT_PART="${BOOT_PART:-/dev/block/by-name/boot}"
echo "[*] waiting for device (recovery)…"; $ADB wait-for-device
$ADB push "$STOCK" /tmp/boot-stock.img
$ADB shell "dd if=/tmp/boot-stock.img of=$BOOT_PART bs=4M && sync && echo RESTORED"
$ADB reboot
echo "[+] stock boot restored; phone rebooting."
