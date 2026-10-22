#!/system/bin/sh
# Make NeoTerm's stock "Kali Shell" session work on this device, without editing
# nhterm's regenerated usr/bin. Two persistent fixes:
set -e
# 1) chroot path the stock wrapper expects -> our real chroot
NH=/data/local/nhsystem
if [ ! -e "$NH/kalifs" ]; then ln -s "$NH/kali-arm64" "$NH/kalifs"; fi
echo "kalifs -> $(readlink $NH/kalifs)"

# 2) a 'su' shim on the wrapper's PATH (home script dir is preserved across relaunch)
SD=/data/data/com.offsec.nhterm/files/home/.nhterm/script
mkdir -p "$SD"
cat > "$SD/su" <<'EOF'
#!/system/bin/sh
for S in /debug_ramdisk/su /sbin/su /system/bin/su /system/xbin/su; do
  [ -x "$S" ] && exec "$S" "$@"
done
echo "su not found"; exit 127
EOF
chmod 755 "$SD/su"
# make sure nhterm app owns it
chown $(stat -c '%u:%g' /data/data/com.offsec.nhterm/files/home 2>/dev/null) "$SD/su" 2>/dev/null || true
echo "su shim: $SD/su"; ls -l "$SD/su"
echo "NHTERM_KALI_FIXED"
