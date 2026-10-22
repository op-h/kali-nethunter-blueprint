#!/system/bin/sh
# =============================================================================
# Repack the stock boot image with the new kernel, keeping Magisk root + the
# device tree, then flash it.  RUN ON THE PHONE as root (adb shell su).
#
# THE #1 CAUSE OF BOOTLOOPS: kernel format mismatch.
#   * Many Samsung/Exynos devices store the kernel UNCOMPRESSED (raw arm64
#     'Image', magic 'ARMd' at offset 0x38) and keep the device tree in a
#     separate "extra"/DTBH section.  Their bootloader does NOT gunzip.
#   * If you flash a gzip 'Image.gz-dtb' where raw is expected, the loader
#     jumps into gzip bytes -> instant logo bootloop.
# This script auto-detects the stock kernel format and matches it.
# =============================================================================
set -e
MB="${MB:-/data/adb/magisk/magiskboot}"          # magiskboot (shipped with Magisk)
BOOT_PART="${BOOT_PART:-/dev/block/by-name/boot}" # adjust: by-name/BOOT on some roms
STOCK_BACKUP="${STOCK_BACKUP:-/sdcard/nh-backup/boot-stock.img}"
NEW_IMAGE_RAW="${NEW_IMAGE_RAW:-/sdcard/nh-backup/Image}"        # uncompressed Image
NEW_IMAGE_GZ="${NEW_IMAGE_GZ:-/sdcard/nh-backup/Image.gz-dtb}"   # gzip+dtb
WORK=/data/local/tmp/nh-repack

echo "[*] 0. ALWAYS keep a backup first:"
echo "    dd if=$BOOT_PART of=$STOCK_BACKUP"
[ -f "$STOCK_BACKUP" ] || { echo "[-] no stock backup at $STOCK_BACKUP - aborting"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
cp "$STOCK_BACKUP" boot.img
$MB unpack boot.img >/dev/null 2>&1

# detect stock kernel format
MAGIC=$(xxd -s 0x38 -l 4 kernel | awk '{print $2$3}')
HEAD=$(xxd -l 3 kernel | awk '{print $2}')
if [ "$MAGIC" = "41524d64" ]; then
    echo "[*] stock kernel = RAW arm64 Image  -> using $NEW_IMAGE_RAW"
    SRC="$NEW_IMAGE_RAW"
elif [ "$HEAD" = "1f8b08" ]; then
    echo "[*] stock kernel = GZIP            -> using $NEW_IMAGE_GZ"
    SRC="$NEW_IMAGE_GZ"
else
    echo "[!] unknown kernel format (magic=$MAGIC head=$HEAD); defaulting to RAW"
    SRC="$NEW_IMAGE_RAW"
fi
[ -f "$SRC" ] || { echo "[-] new kernel $SRC not found"; exit 1; }

cp "$SRC" kernel          # swap ONLY the kernel; ramdisk (Magisk) + extra(DTBH) stay
$MB repack boot.img new-boot.img >/dev/null 2>&1
echo "[*] repacked new-boot.img:"; ls -la new-boot.img

echo "[*] flashing to $BOOT_PART ..."
dd if=new-boot.img of="$BOOT_PART" bs=4M
sync
echo "[+] flashed. Reboot to test. If it bootloops -> boot/recovery.sh"
