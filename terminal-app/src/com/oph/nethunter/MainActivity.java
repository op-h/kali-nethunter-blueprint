package com.oph.nethunter;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Toast;

/**
 * Kali NetHunter launcher (op-h).
 * One tap -> opens the NetHunter Terminal straight into the enhanced Kali zsh.
 * The enhanced shell + a fixed "Kali Shell" session are set up on-device, so
 * simply launching NeoTermActivity drops the user into the themed Kali prompt.
 */
public class MainActivity extends Activity {
    private static final String NHTERM_PKG = "com.offsec.nhterm";
    private static final String NHTERM_ACT = "com.offsec.nhterm.ui.term.NeoTermActivity";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (!launchNetHunterTerminal()) {
            Toast.makeText(this,
                "NetHunter Terminal (com.offsec.nhterm) not found. Install the NetHunter store app first.",
                Toast.LENGTH_LONG).show();
        }
        finish();
    }

    private boolean launchNetHunterTerminal() {
        // Preferred: start the terminal activity directly (opens the Kali Shell session).
        try {
            Intent i = new Intent(Intent.ACTION_MAIN);
            i.setComponent(new ComponentName(NHTERM_PKG, NHTERM_ACT));
            i.addCategory(Intent.CATEGORY_LAUNCHER);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            startActivity(i);
            return true;
        } catch (Exception ignored) { }

        // Fallback: whatever launch intent the system has for the package.
        try {
            Intent i = getPackageManager().getLaunchIntentForPackage(NHTERM_PKG);
            if (i != null) {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
                return true;
            }
        } catch (Exception ignored) { }

        return false;
    }
}
