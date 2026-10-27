#!/system/bin/sh
# ctrlc-fix.sh — stop Ctrl+C from closing the whole NetHunter Terminal tab.
#
# THE PROBLEM
#   NeoTerm's "kali" wrapper launches the session as:
#       bash(wrapper) -> su(android) -> chroot -> su(kali) -> zsh
#   with NO `exec` anywhere, so every process sits in ONE foreground process
#   group. Pressing Ctrl+C sends SIGINT to that whole group; the non-interactive
#   bash/su/chroot parents have no handler and die, tearing the session down with
#   "[Process completed (signal 2) - press Enter]" instead of just interrupting
#   the running command.
#
# THE FIX  (lives INSIDE the chroot, so it survives NeoTerm regenerating its own
#           usr/bin — never edit NeoTerm's generated `kali` wrapper)
#   Give the interactive zsh its own session + controlling terminal via
#   `setsid -c`. Then Ctrl+C reaches ONLY zsh and its current foreground job
#   (e.g. wifite) — never the Android-side parents. A `su -c '...'` automation
#   path is kept intact (plain zsh, no new session) so scripts still work.
#
# USAGE (run as root on the phone):
#   adb push nhterm-fix/ctrlc-fix.sh /data/local/tmp/
#   adb shell su -c 'sh /data/local/tmp/ctrlc-fix.sh'
#
# Override the chroot path for other devices:
#   KROOT=/data/local/nhsystem/<your-rootfs> sh ctrlc-fix.sh

set -e
KROOT="${KROOT:-/data/local/nhsystem/kali-arm64}"
PASSWD="$KROOT/etc/passwd"
WRAPPER="$KROOT/usr/bin/kali-login-shell"

[ -f "$PASSWD" ] || { echo "ERROR: $PASSWD not found (is the chroot path right?)"; exit 1; }

echo "[*] chroot     = $KROOT"
echo "[*] shell path = $(grep '^root:' "$PASSWD" | cut -d: -f7 2>/dev/null || sed -n 's/^root:.*:\(.*\)$/\1/p' "$PASSWD")"

# 1) back up passwd once
if [ ! -f "$PASSWD.bak-ctrlc" ]; then
  cp "$PASSWD" "$PASSWD.bak-ctrlc"
  echo "[+] backed up passwd -> $PASSWD.bak-ctrlc"
else
  echo "[=] backup already exists, keeping it"
fi

# 2) write the login-shell wrapper (absolute paths so it never needs PATH)
cat > "$WRAPPER" <<'EOF'
#!/bin/bash
# OPH: give the interactive Kali shell its own session (setsid -c) so Ctrl+C
# reaches only this shell and its foreground job, never the Android-side
# bash/su/chroot parents (which would otherwise die and close the terminal tab).
if [ "$#" -eq 0 ] && [ -t 0 ]; then
    exec /usr/bin/setsid -c /usr/bin/zsh -i
else
    # non-interactive (su -c '...') or no tty: run plainly, don't break automation
    exec /usr/bin/zsh "$@"
fi
EOF
chmod 0755 "$WRAPPER"
echo "[+] wrote $WRAPPER"

# 3) point root's login shell at the wrapper (only the root line's last field)
sed -i 's#^\(root:x:0:0:root:/root:\).*#\1/usr/bin/kali-login-shell#' "$PASSWD"
echo "[+] root login shell -> /usr/bin/kali-login-shell"
grep '^root:' "$PASSWD"

# 4) sanity: automation path (su -c) must still run commands
echo "[*] sanity check (command mode):"
/system/bin/chroot "$KROOT" /bin/su -c 'echo "    OK -> $(whoami)"'

echo
echo "[DONE] Open the NetHunter Terminal:"
echo "   - at the prompt, Ctrl+C just clears the line (won't exit)"
echo "   - while a tool runs, Ctrl+C stops that tool and returns to the prompt"
echo "To revert:  cp $PASSWD.bak-ctrlc $PASSWD"
