# Claude Code agents — port this blueprint to any phone

A set of [Claude Code](https://claude.com/claude-code) subagents that reproduce this
whole project on a **different** rooted Android phone, safely and in the right order.
Each agent owns one phase and carries the hard-won gotchas from the Note 9 build so you
don't rediscover them.

## Install

Copy the agents where Claude Code looks for them:

```bash
# project-scoped (only in this repo)
cp -r .claude/agents /path/to/your/project/.claude/

# or user-scoped (available everywhere)
mkdir -p ~/.claude/agents && cp .claude/agents/*.md ~/.claude/agents/
```

Then in Claude Code: `/agents` to list them, or just ask — the orchestrator is invoked
by describing the goal ("port NetHunter to my <device>"). Agents are also callable by
name via the Task/Agent tool.

## The agents

| Agent | Phase | What it does |
|---|---|---|
| `nethunter-orchestrator` | coordinate | Runs the phases in order, gates each on a safe checkpoint, delegates to the specialists below. |
| `device-recon` | 0 · discover | Reads chipset, kernel commit, boot-image format, `/proc/config.gz`, root status — produces the per-device profile everything else keys off. |
| `kernel-builder` | 1 · build | Cross-compiles the NetHunter kernel (config.gz base, clang + GNU `as`, NetHunter patches). |
| `boot-flasher` | 2 · flash | Repacks raw `Image` keeping ramdisk + DTBH, `dd`s it, and **always** stages the stock-restore recovery first. |
| `chroot-shell` | 3 · shell | Enhances the Kali zsh, fixes NeoTerm's "Kali Shell", applies the Ctrl+C session fix. |
| `usb-wifi-driver` | 4 · wifi | Builds an external USB adapter driver as a Magisk module (the `-fno-stack-protector` PAN fix). |
| `launcher-app` | 5 · app | Builds + signs the one-tap launcher APK without Gradle. |
| `device-theme` | 6 · theme | Dark/black theme, accent, wallpaper, Lawnchair + Arcticons, debloat. |
| `verify-test` | 7 · verify | Confirms kernel features live, drives authorized Wi-Fi tests, checks nothing bootlooped. |

## Golden rules baked into every agent

1. **Back up `boot.img` before touching the boot partition.** It is the only lifeline.
2. **Base the kernel config on the phone's own `/proc/config.gz`**, never a bare `*_defconfig`.
3. **Check the boot-image kernel format** (raw `Image` vs `Image.gz-dtb`) before flashing.
4. **One change at a time, verify, keep the connection.** Never run `airmon-ng check kill`
   (it kills Android's wpa_supplicant and drops wireless ADB).
5. **Authorized targets only** — attack only networks/devices the user owns or is permitted to test.
