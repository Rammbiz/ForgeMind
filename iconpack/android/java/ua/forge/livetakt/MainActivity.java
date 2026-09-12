package ua.forge.livetakt;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Toast;

/**
 * A one-screen dashboard: what the pack is, and one tap to hand it to the
 * launcher.  Launchers that support icon packs all listen for their own apply
 * intent, so each button fires the matching one and falls back to a hint.
 */
public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }

    public void applyNova(View view) {
        Intent intent = new Intent("com.teslacoilsw.launcher.APPLY_ICON_THEME");
        intent.setPackage("com.teslacoilsw.launcher");
        intent.putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_TYPE", "GO");
        intent.putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_PACKAGE", getPackageName());
        start(intent, R.string.apply_missing_nova);
    }

    public void applyLawnchair(View view) {
        Intent intent = new Intent("ch.deletescape.lawnchair.APPLY_ICONS");
        intent.putExtra("packageName", getPackageName());
        start(intent, R.string.apply_missing_lawnchair);
    }

    public void applySmart(View view) {
        Intent intent = new Intent("ginlemon.smartlauncher.setGSLTHEME");
        intent.putExtra("package", getPackageName());
        start(intent, R.string.apply_missing_smart);
    }

    public void applyAdw(View view) {
        Intent intent = new Intent("org.adw.launcher.SET_THEME");
        intent.putExtra("org.adw.launcher.theme", getPackageName());
        start(intent, R.string.apply_manual);
    }

    private void start(Intent intent, int failureMessage) {
        try {
            startActivity(intent);
        } catch (ActivityNotFoundException missing) {
            Toast.makeText(this, getString(failureMessage), Toast.LENGTH_LONG).show();
        }
    }
}
