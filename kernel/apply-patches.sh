#!/usr/bin/env bash
# Download + apply the official Kali NetHunter kernel patches for 4.9 kernels.
# Run from inside the kernel source tree (cwd = .../kernel).
set -euo pipefail
RAW="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches"
PVER="${PVER:-4.09}"   # patch set matching your kernel major.minor (4.09 covers 4.9)
TMP="$(mktemp -d)"

# the 4.09 set: wifi injection, rtl88xxau driver, ath9k fix, UB500 bluetooth
for f in add-wifi-injection-4.14.patch fix-ath9k-naming-conflict.patch \
         add-ub500-to-btusb.patch add-rtl88xxau-5.6.4.2-drivers.patch; do
    # some entries are symlinks to ../4.14 or ../4.04 in the repo; the API resolves them
    curl -fsSL "$RAW/$PVER/$f" -o "$TMP/$f" || curl -fsSL "$RAW/4.14/$f" -o "$TMP/$f" || curl -fsSL "$RAW/4.04/$f" -o "$TMP/$f"
done

for f in add-wifi-injection-4.14.patch fix-ath9k-naming-conflict.patch \
         add-ub500-to-btusb.patch add-rtl88xxau-5.6.4.2-drivers.patch; do
    if git apply --check -p1 "$TMP/$f" 2>/dev/null; then
        git apply -p1 "$TMP/$f" && echo "[+] applied $f"
    else
        echo "[!] $f did not apply cleanly - review manually" >&2
    fi
done
rm -rf "$TMP"
