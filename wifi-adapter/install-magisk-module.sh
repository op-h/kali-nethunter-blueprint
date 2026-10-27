#!/system/bin/sh
# install-magisk-module.sh — package the built rtl88x2bu.ko as a Magisk module
# that insmods the driver at every boot, so the USB Wi-Fi adapter is plug-and-play
# (plug adapter -> wlan1 appears) with no kernel reflash.
#
# USAGE (run as root on the phone):
#   adb push 88x2bu.ko /data/local/tmp/
#   adb push wifi-adapter/install-magisk-module.sh /data/local/tmp/
#   adb shell su -c 'sh /data/local/tmp/install-magisk-module.sh /data/local/tmp/88x2bu.ko'
#
# Then unplug/replug the adapter (or reboot): `ip link show wlan1` should appear.

set -e
KO="${1:-/data/local/tmp/88x2bu.ko}"
MOD=/data/adb/modules/rtl88x2bu

[ -f "$KO" ] || { echo "ERROR: .ko not found: $KO"; exit 1; }
[ -d /data/adb/modules ] || { echo "ERROR: Magisk modules dir missing (is Magisk installed?)"; exit 1; }

echo "[*] installing $KO -> $MOD"
mkdir -p "$MOD"
cp "$KO" "$MOD/88x2bu.ko"

cat > "$MOD/module.prop" <<'EOF'
id=rtl88x2bu
name=RTL8812BU USB Wi-Fi (NetHunter)
version=v1.0
versionCode=1
author=OPH
description=Loads the rtl88x2bu driver at boot so RTL8812BU USB adapters give wlan1 (monitor + injection). Built with -fno-stack-protector to avoid the PAN fault on probe.
EOF

# service.sh runs late in boot (after /data is mounted) — insmod the driver
cat > "$MOD/service.sh" <<'EOF'
#!/system/bin/sh
# wait for the module file, then load it (ignore "File exists" on re-runs)
MODDIR=${0%/*}
until [ -b /dev/block/by-name/userdata ] || [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
insmod "$MODDIR/88x2bu.ko" 2>/dev/null
EOF
chmod 0755 "$MOD/service.sh"

echo "[+] module.prop + service.sh written"
echo "[*] loading now for this boot..."
insmod "$MOD/88x2bu.ko" 2>/dev/null && echo "    loaded" || echo "    already loaded (ok)"
lsmod | grep -i 88x2 || true

echo
echo "[DONE] plug the RTL8812BU adapter via OTG; 'ip link show wlan1' should appear."
echo "       keep the screen awake — the Note 9 cuts OTG power when it sleeps."
