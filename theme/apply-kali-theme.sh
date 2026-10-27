#!/system/bin/sh
# apply-kali-theme.sh — turn a LineageOS phone into a dark, Kali-looking device.
#
# Scope (all reversible, no system image changes):
#   - force the system dark / black theme + a Kali-blue accent
#   - set the Kali dragon wallpaper (home + lock)
#   - (manual) Lawnchair launcher + Arcticons line-art icon pack
#   - (manual) custom boot animation + sounds
#
# USAGE (run as root on the phone):
#   adb shell su -c 'sh /data/local/tmp/apply-kali-theme.sh'
#
# NOTE: Stock Launcher3 does NOT support icon packs (only themed-icons + shape),
# which is why a Lawnchair + Arcticons step is needed for the uniform line-art look.

set -e
ACCENT="${ACCENT:-1793D1}"   # Kali blue

echo "[*] enabling dark + black theme"
cmd uimode night yes 2>/dev/null || settings put secure ui_night_mode 2 2>/dev/null || true
# LineageOS black (true-black) theme overlay
cmd overlay enable org.lineageos.overlay.customization.blacktheme 2>/dev/null || true

echo "[*] setting Kali-blue Monet accent ($ACCENT)"
settings put secure theme_customization_overlay_packages \
  "{\"android.theme.customization.accent_color\":\"$ACCENT\",\"android.theme.customization.theme_style\":\"TONAL_SPOT\"}" 2>/dev/null || true

echo "[*] wallpaper"
echo "    Scoped storage blocks reading /sdcard from a generic broadcast, so set"
echo "    the wallpaper with a tiny helper that calls WallpaperManager.setBitmap"
echo "    (FLAG_SYSTEM|FLAG_LOCK) reading from the app's own files dir, OR simply:"
echo "      Settings > Wallpaper > pick theme/kali-dragon.png for home + lock"

cat <<'NOTE'

[MANUAL STEPS] (one-time, from the phone UI):

  1) Launcher + icons (uniform line-art):
     - Install Lawnchair (ch.deletescape.lawnchair) + Arcticons icon pack (F-Droid).
     - Set Lawnchair as default launcher.
     - Lawnchair > Settings > General > Theme = Dark/Black.
     - Lawnchair > Settings > Icon Style > Icon pack = Arcticons.
     - Lawnchair > Debug menu > "Rebuild icon database" (forces the pack to apply).
     - For apps with no appfilter mapping (e.g. F-Droid): long-press app > Edit >
       tap the icon > pick the matching Arcticons glyph manually.

  2) Debloat + privacy apps (reversible):
     - pm uninstall --user 0 <pkg>   # removes for current user, restorable
     - Install from F-Droid: Fennec (Firefox), Tor Browser, Termux,
       WiFiAnalyzer, Fossify Gallery.

  3) (optional) Boot animation + sounds:
     - /system (or a Magisk module) bootanimation.zip for the Kali boot logo.
     - settings put system ringtone|notification_sound|alarm_alert \
         content://media/external/audio/media/<id>   (after adding WAVs to media)

NOTE
echo "[DONE] dark theme + accent applied; finish the manual launcher/icon steps above."
