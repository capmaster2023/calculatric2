#!/usr/bin/env bash
set -e
APP=android/app/src/main
# App name
mkdir -p "$APP/res/values"
cat > "$APP/res/values/strings.xml" <<'EOF'
<resources>
    <string name="app_name">Calculatrice</string>
    <string name="title_activity_main">Calculatrice</string>
    <string name="package_name">com.capmaster2023.calculatrice</string>
    <string name="custom_url_scheme">com.capmaster2023.calculatrice</string>
</resources>
EOF
# Icons
mkdir -p "$APP/res/mipmap-mdpi" "$APP/res/mipmap-hdpi" "$APP/res/mipmap-xhdpi" "$APP/res/mipmap-xxhdpi" "$APP/res/mipmap-xxxhdpi"
cp android-res/icon-48.png "$APP/res/mipmap-mdpi/ic_launcher.png"
cp android-res/icon-48.png "$APP/res/mipmap-mdpi/ic_launcher_round.png"
cp android-res/icon-72.png "$APP/res/mipmap-hdpi/ic_launcher.png"
cp android-res/icon-72.png "$APP/res/mipmap-hdpi/ic_launcher_round.png"
cp android-res/icon-96.png "$APP/res/mipmap-xhdpi/ic_launcher.png"
cp android-res/icon-96.png "$APP/res/mipmap-xhdpi/ic_launcher_round.png"
cp android-res/icon-144.png "$APP/res/mipmap-xxhdpi/ic_launcher.png"
cp android-res/icon-144.png "$APP/res/mipmap-xxhdpi/ic_launcher_round.png"
cp android-res/icon-192.png "$APP/res/mipmap-xxxhdpi/ic_launcher.png"
cp android-res/icon-192.png "$APP/res/mipmap-xxxhdpi/ic_launcher_round.png"
# Disable backups in manifest and allow app to reset UI on pause via JS. Keep screenshot preview as calculator if app is backgrounded.
python3 - <<'PY2'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if '<uses-permission android:name="android.permission.INTERNET"' not in s:
    s=s.replace('<manifest ', '<manifest ', 1)
    s=s.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n<application', 1)
if 'android:allowBackup=' not in s:
    s=s.replace('<application ', '<application android:allowBackup="false" android:fullBackupContent="false" ',1)
else:
    import re
    s=re.sub(r'android:allowBackup="[^"]*"','android:allowBackup="false"',s)
if 'android:usesCleartextTraffic=' not in s:
    s=s.replace('<application ', '<application android:usesCleartextTraffic="true" ',1)
p.write_text(s)
PY2

# Native ExoPlayer video bridge: plays videos with Android native decoder instead of WebView <video>.
PKG_DIR="$APP/java/com/capmaster2023/calculatrice"
mkdir -p "$PKG_DIR"
cat > "$PKG_DIR/NativeVideoPlugin.java" <<'EOFJAVA'
package com.capmaster2023.calculatrice;

import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.util.Base64;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@CapacitorPlugin(name = "NativeVideo")
public class NativeVideoPlugin extends Plugin {
    private final Map<String, File> sessions = new HashMap<>();

    @PluginMethod
    public void wipeNativeCache(PluginCall call) {
        try {
            File dir = new File(getContext().getCacheDir(), "native_video");
            deleteRecursive(dir);
            sessions.clear();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    private void deleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File c : children) deleteRecursive(c);
        }
        try { f.delete(); } catch (Exception ignored) {}
    }

    @PluginMethod
    public void startSession(PluginCall call) {
        try {
            String name = call.getString("name", "video");
            String safe = name.replaceAll("[^a-zA-Z0-9._-]", "_");
            if (!safe.contains(".")) safe += ".mp4";
            String id = UUID.randomUUID().toString();
            File dir = new File(getContext().getCacheDir(), "native_video");
            if (!dir.exists()) dir.mkdirs();
            File file = new File(dir, id + "_" + safe);
            sessions.put(id, file);
            JSObject ret = new JSObject();
            ret.put("sessionId", id);
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void appendChunk(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            String b64 = call.getString("base64");
            File file = sessions.get(id);
            if (file == null) { call.reject("Session vidéo introuvable"); return; }
            byte[] data = Base64.decode(b64, Base64.DEFAULT);
            FileOutputStream out = new FileOutputStream(file, true);
            out.write(data);
            out.close();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void finishThumbnail(PluginCall call) {
        File file = null;
        MediaMetadataRetriever retriever = null;
        try {
            String id = call.getString("sessionId");
            file = sessions.remove(id);
            if (file == null || !file.exists()) { call.reject("Fichier vidéo introuvable"); return; }
            retriever = new MediaMetadataRetriever();
            retriever.setDataSource(file.getAbsolutePath());
            String d = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            long durationMs = 0;
            try { durationMs = Long.parseLong(d == null ? "0" : d); } catch (Exception ignored) {}
            long timeUs = durationMs > 0 ? (durationMs * 1000L / 2L) : 1000000L;
            Bitmap bmp = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if (bmp == null) bmp = retriever.getFrameAtTime(1000000L, MediaMetadataRetriever.OPTION_CLOSEST);
            if (bmp == null) { call.reject("Preview vidéo impossible"); return; }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.JPEG, 78, out);
            JSObject ret = new JSObject();
            ret.put("thumbnail", Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP));
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
        finally {
            try { if (retriever != null) retriever.release(); } catch (Exception ignored) {}
            try { if (file != null) file.delete(); } catch (Exception ignored) {}
        }
    }

    @PluginMethod
    public void finishAndPlay(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            String title = call.getString("title", "Vidéo");
            File file = sessions.remove(id);
            if (file == null || !file.exists()) { call.reject("Fichier vidéo introuvable"); return; }
            Intent intent = new Intent(getContext(), NativeVideoActivity.class);
            intent.putExtra("path", file.getAbsolutePath());
            intent.putExtra("title", title);
            getActivity().startActivity(intent);
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }
}
EOFJAVA

cat > "$PKG_DIR/NativeVideoActivity.java" <<'EOFJAVA'
package com.capmaster2023.calculatrice;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.view.ViewGroup;
import androidx.media3.common.MediaItem;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;
import java.io.File;

public class NativeVideoActivity extends Activity {
    private ExoPlayer player;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        String path = getIntent().getStringExtra("path");
        PlayerView playerView = new PlayerView(this);
        playerView.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        setContentView(playerView);
        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);
        player.setMediaItem(MediaItem.fromUri(Uri.fromFile(new File(path))));
        player.prepare();
        player.play();
    }

    @Override protected void onStop() { super.onStop(); if (player != null) player.pause(); }
    @Override protected void onDestroy() { if (player != null) { player.release(); player = null; } super.onDestroy(); }
}
EOFJAVA


cat > "$PKG_DIR/NativeDownloaderPlugin.java" <<'EOFJAVA'
package com.capmaster2023.calculatrice;

import android.webkit.MimeTypeMap;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import android.util.Base64;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@CapacitorPlugin(name = "NativeDownloader")
public class NativeDownloaderPlugin extends Plugin {
    private final Map<String, File> sessions = new HashMap<>();

    @PluginMethod
    public void wipeDownloads(PluginCall call) {
        try {
            deleteRecursive(new File(getContext().getCacheDir(), "private_downloads"));
            sessions.clear();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void deleteSession(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            File f = sessions.remove(id);
            if (f != null) f.delete();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void downloadUrl(PluginCall call) {
        String raw = call.getString("url");
        if (raw == null || !(raw.startsWith("http://") || raw.startsWith("https://"))) {
            call.reject("Lien invalide"); return;
        }
        new Thread(() -> {
            HttpURLConnection conn = null;
            try {
                URL url = new URL(raw);
                conn = (HttpURLConnection) url.openConnection();
                conn.setInstanceFollowRedirects(true);
                conn.setConnectTimeout(20000);
                conn.setReadTimeout(60000);
                conn.setRequestProperty("User-Agent", "Mozilla/5.0 Android Calculatrice");
                conn.connect();
                int code = conn.getResponseCode();
                if (code < 200 || code >= 300) { call.reject("Serveur HTTP " + code); return; }
                String type = conn.getContentType();
                if (type != null && type.contains(";")) type = type.split(";",2)[0].trim();
                if (type == null || type.length() == 0) type = "application/octet-stream";
                String name = guessFileName(raw, conn.getHeaderField("Content-Disposition"), type);
                File dir = new File(getContext().getCacheDir(), "private_downloads");
                if (!dir.exists()) dir.mkdirs();
                String id = UUID.randomUUID().toString();
                File outFile = new File(dir, id + "_" + name.replaceAll("[^a-zA-Z0-9._-]", "_"));
                InputStream in = conn.getInputStream();
                FileOutputStream out = new FileOutputStream(outFile);
                byte[] buf = new byte[1024 * 256];
                int n;
                while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
                out.close(); in.close();
                sessions.put(id, outFile);
                JSObject ret = new JSObject();
                ret.put("sessionId", id);
                ret.put("name", name);
                ret.put("type", type);
                ret.put("size", outFile.length());
                call.resolve(ret);
            } catch (Exception e) { call.reject(e.getMessage(), e); }
            finally { if (conn != null) conn.disconnect(); }
        }).start();
    }

    @PluginMethod
    public void readChunk(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            int seq = call.getInt("seq", 0);
            int chunkSize = call.getInt("chunkSize", 4 * 1024 * 1024);
            File f = sessions.get(id);
            if (f == null || !f.exists()) { call.reject("Téléchargement introuvable"); return; }
            long offset = (long) seq * (long) chunkSize;
            FileInputStream in = new FileInputStream(f);
            long skipped = in.skip(offset);
            if (skipped < offset) { in.close(); call.reject("Morceau introuvable"); return; }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[Math.min(chunkSize, 1024 * 256)];
            int remaining = chunkSize;
            while (remaining > 0) {
                int n = in.read(buf, 0, Math.min(buf.length, remaining));
                if (n == -1) break;
                out.write(buf, 0, n);
                remaining -= n;
            }
            in.close();
            JSObject ret = new JSObject();
            ret.put("base64", Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP));
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    private String guessFileName(String raw, String cd, String type) {
        try {
            if (cd != null && cd.contains("filename=")) {
                String n = cd.substring(cd.indexOf("filename=") + 9).replace("\"", "").trim();
                if (n.length() > 0) return n;
            }
            String path = new URL(raw).getPath();
            String n = path.substring(path.lastIndexOf('/') + 1);
            n = URLDecoder.decode(n, "UTF-8");
            if (n.length() > 0 && n.contains(".")) return n;
            String ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(type);
            if (ext == null || ext.length() == 0) ext = type.startsWith("video/") ? "mp4" : "bin";
            return "download_" + System.currentTimeMillis() + "." + ext;
        } catch (Exception e) { return "download_" + System.currentTimeMillis() + ".mp4"; }
    }

    private void deleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File c : children) deleteRecursive(c);
        }
        try { f.delete(); } catch (Exception ignored) {}
    }
}
EOFJAVA

cat > "$PKG_DIR/MainActivity.java" <<'EOFJAVA'
package com.capmaster2023.calculatrice;

import android.os.Bundle;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(NativeVideoPlugin.class);
        registerPlugin(NativeDownloaderPlugin.class);
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onPause() {
        forceCalculatorScreen();
        super.onPause();
    }

    @Override
    protected void onStop() {
        forceCalculatorScreen();
        super.onStop();
    }

    private void forceCalculatorScreen() {
        try {
            if (getBridge() == null || getBridge().getWebView() == null) return;
            WebView webView = getBridge().getWebView();
            webView.post(() -> {
                try { webView.loadUrl("file:///android_asset/public/index.html"); } catch (Exception ignored) {}
            });
        } catch (Exception ignored) {}
    }
}
EOFJAVA

python3 - <<'PY3'
from pathlib import Path
# Add ExoPlayer/Media3 dependencies
p=Path('android/app/build.gradle')
s=p.read_text()
if 'androidx.media3:media3-exoplayer' not in s:
    s=s.replace('dependencies {', 'dependencies {\n    implementation "androidx.media3:media3-exoplayer:1.4.1"\n    implementation "androidx.media3:media3-ui:1.4.1"', 1)
p.write_text(s)
# Register activity in manifest
m=Path('android/app/src/main/AndroidManifest.xml')
s=m.read_text()
if 'NativeVideoActivity' not in s:
    s=s.replace('</application>', '    <activity android:name=".NativeVideoActivity" android:screenOrientation="fullSensor" android:configChanges="orientation|screenSize|keyboardHidden" />\n</application>', 1)
m.write_text(s)
PY3
