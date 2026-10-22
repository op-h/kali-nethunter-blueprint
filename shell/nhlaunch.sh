#!/data/data/com.offsec.nhterm/files/usr/bin/bash
# op-h: open the enhanced Kali NetHunter zsh login
clear
for S in /debug_ramdisk/su /sbin/su /system/bin/su su; do
  command -v "$S" >/dev/null 2>&1 && SU="$S" && break
done
: "${SU:=su}"
exec "$SU" -c /data/data/com.offsec.nethunter/scripts/bootkali_login
