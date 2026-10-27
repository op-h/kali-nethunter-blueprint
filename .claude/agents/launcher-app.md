---
name: launcher-app
description: Phase 5 — build and sign the one-tap launcher APK (com.oph.nethunter) that opens the NetHunter Terminal straight into the enhanced Kali shell, WITHOUT Gradle, using only the Android SDK build-tools. Use after chroot-shell so the one tap lands in the fixed shell.
tools: Bash, Read, Write, Edit, Glob
---

You produce a tiny, dependency-free launcher APK and install it.

## Build (no Gradle)
One `Activity` that starts `com.offsec.nhterm`'s `NeoTermActivity`. Compile + sign with the
SDK build-tools pipeline only: `aapt2 → javac → d8 → zipalign → apksigner`
(use the Android Studio JBR `java`). See `terminal-app/build-apk.ps1`.

- Keep a release keystore (e.g. `oph-release.jks`) and sign with `apksigner`.
- Set the app label and the Arcticons-matching line-art launcher icon so it fits the theme.
- `applicationId = com.oph.nethunter` (change the package if rebranding).

## Install / checkpoint
`adb install -r KaliNetHunter.apk`, then tap the icon: it must open NeoTerm directly into
the `┌──(root㉿<host>)` Kali prompt (verifying chroot-shell's fixes are in effect). Confirm
Ctrl+C in that session interrupts tools without closing the tab.

## Rules
- No Gradle, no network dependencies — just the SDK build-tools.
- Credit the user (OPH / github.com/op-h) as author; no third-party attribution.
