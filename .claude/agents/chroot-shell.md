---
name: chroot-shell
description: Phase 3 — make the Kali chroot pleasant and the NetHunter Terminal reliable. Installs the enhanced zsh (Kali prompt, autosuggestions, nh/tools menus), fixes NeoTerm's "Kali Shell" session, and applies the Ctrl+C session fix so interrupting a tool no longer closes the tab. Use after the new kernel boots.
tools: Bash, Read, Write, Edit, Grep
---

You make the shell usable. All changes live INSIDE the chroot so NeoTerm regenerating its
own `usr/bin` can't undo them.

## Tasks
1. **Enhanced zsh** (`setup-kali-shell.sh`): install `zsh` + zsh-autosuggestions +
   zsh-syntax-highlighting, write the authentic Kali two-line prompt, and add `nh`
   (interactive categorized tool launcher) and `tools` (inventory) functions. Set root's
   shell to zsh.
2. **NeoTerm "Kali Shell" fix** (`fix-nhterm-kali.sh`): DON'T edit NeoTerm's auto-generated
   `kali` wrapper. Instead make two persistent fixes: symlink
   `/data/local/nhsystem/kalifs -> <rootfs>` and a `su` shim at
   `.../com.offsec.nhterm/files/home/.nhterm/script/su` that execs the real Magisk `su`
   (NeoTerm's wrapper does `which su` on a PATH lacking Magisk's su).
3. **Ctrl+C session fix** (`ctrlc-fix.sh`): the wrapper chains
   `bash→su→chroot→su→zsh` with no `exec`, so all share one process group and Ctrl+C's
   SIGINT kills the non-interactive parents → the tab closes with "signal 2". Fix: add
   `/usr/bin/kali-login-shell` that does `exec /usr/bin/setsid -c /usr/bin/zsh -i` for an
   interactive session (and plain `exec zsh "$@"` for `su -c` automation), then point
   root's shell in `/etc/passwd` at it (back up passwd first). `setsid -c` gives zsh its
   own session + controlling tty, so Ctrl+C reaches only zsh and its foreground job.

## Checkpoint
Open the terminal: it lands in `┌──(root㉿<host>)` prompt; at the prompt Ctrl+C clears the
line (no exit); while a tool runs Ctrl+C interrupts the tool and returns to the prompt.

## Rules
- Verify `setsid` exists in the chroot (`/usr/bin/setsid`); use absolute paths in the wrapper.
- Keep a `/etc/passwd.bak-ctrlc` backup so the shell change is reversible.
