package org.love2d.android;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.graphics.Rect;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.DisplayCutout;
import android.view.WindowManager;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import org.libsdl.app.SDLActivity;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.rewarded.RewardItem;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.gms.ads.OnUserEarnedRewardListener;

public class GameActivity extends SDLActivity {
    private static final String TAG  = "GameActivity";
    private static final String ADTAG = "AdMobGame";
    public static final int RECORD_AUDIO_REQUEST_CODE = 3;

    // =====================================================
    // AdMob — Ad Unit ID الحقيقي
    // =====================================================
    private static final String AD_UNIT_ID = "ca-app-pub-6579039670331148/1684062115";

    private RewardedAd rewardedAd = null;
    private volatile boolean adRewardGranted = false;

    // =====================================================

    protected Vibrator vibrator;
    protected boolean shortEdgesMode;
    protected final int[] recordAudioRequestDummy = new int[1];
    private Uri delayedUri = null;
    private String[] args;
    private boolean isFused;

    private static native void nativeSetDefaultStreamValues(int sampleRate, int framesPerBurst);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "started");
        isFused = hasEmbeddedGame();
        args    = new String[0];

        // تهيئة AdMob
        MobileAds.initialize(this, initializationStatus -> {
            Log.d(ADTAG, "AdMob initialized");
            loadRewardedAd();
        });

        if (checkCallingOrSelfPermission(Manifest.permission.VIBRATE) == PackageManager.PERMISSION_GRANTED) {
            vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        }

        Intent intent = getIntent();
        handleIntent(intent, true);
        intent.setData(null);

        super.onCreate(savedInstanceState);
        if (mBrokenLibraries) return;

        nativeSetDefaultStreamValues(getAudioFreq(), getAudioSMP());

        if (android.os.Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams attr = getWindow().getAttributes();
            attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
            shortEdgesMode = false;
        }

        if (delayedUri != null) {
            sendUriAsDroppedFile(delayedUri);
            delayedUri = null;
        }
    }

    // =====================================================
    // تحميل الإعلان في الخلفية
    // =====================================================
    @Keep
    public void loadRewardedAd() {
        runOnUiThread(() -> {
            AdRequest adRequest = new AdRequest.Builder().build();
            RewardedAd.load(this, AD_UNIT_ID, adRequest, new RewardedAdLoadCallback() {
                @Override
                public void onAdFailedToLoad(@NonNull LoadAdError error) {
                    Log.d(ADTAG, "Ad failed to load: " + error.getMessage());
                    rewardedAd = null;
                }
                @Override
                public void onAdLoaded(@NonNull RewardedAd ad) {
                    Log.d(ADTAG, "Ad loaded and ready");
                    rewardedAd = ad;
                }
            });
        });
    }

    // =====================================================
    // عرض الإعلان — يُستدعى من Lua
    // =====================================================
    @Keep
    public void showRewardedAd() {
        runOnUiThread(() -> {
            if (rewardedAd != null) {
                rewardedAd.show(this, rewardItem -> {
                    Log.d(ADTAG, "User earned reward: " + rewardItem.getAmount());
                    adRewardGranted = true;   // Lua ستقرأ هذا عبر pollAdReward()
                    rewardedAd = null;
                    loadRewardedAd();         // حمّل الإعلان التالي فوراً
                });
            } else {
                Log.d(ADTAG, "Ad not ready yet, retrying load");
                loadRewardedAd();
            }
        });
    }

    // =====================================================
    // Lua تسأل في كل frame: هل انتهى الإعلان وتمت المكافأة؟
    // =====================================================
    @Keep
    public boolean pollAdReward() {
        if (adRewardGranted) {
            adRewardGranted = false;
            return true;
        }
        return false;
    }

    // هل الإعلان محمّل وجاهز؟
    @Keep
    public boolean isAdReady() {
        return rewardedAd != null;
    }

    // =====================================================
    // باقي كود GameActivity الأصلي
    // =====================================================

    @Override
    protected String getMainSharedObject() {
        String[] libs = getLibraries();
        return "lib" + libs[libs.length - 1] + ".so";
    }

    @Override
    protected String[] getLibraries() {
        return new String[]{
            "c++_shared", "SDL3", "oboe", "openal", "luajit", "liblove", "love",
        };
    }

    @Override
    protected String[] getArguments() { return args; }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent, false);
    }

    @Override
    protected void onDestroy() {
        if (vibrator != null) vibrator.cancel();
        super.onDestroy();
    }

    @Override
    protected void onPause() {
        if (vibrator != null) vibrator.cancel();
        super.onPause();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (grantResults.length > 0) {
            if (requestCode == RECORD_AUDIO_REQUEST_CODE) {
                synchronized (recordAudioRequestDummy) {
                    recordAudioRequestDummy[0] = grantResults[0];
                    recordAudioRequestDummy.notify();
                }
            } else {
                super.onRequestPermissionsResult(requestCode, permissions, grantResults);
            }
        }
    }

    @Keep
    public boolean hasEmbeddedGame() {
        AssetManager am = getAssets();
        InputStream inputStream;
        try { inputStream = am.open("main.lua"); }
        catch (IOException e) {
            try { inputStream = am.open("game.love"); }
            catch (IOException e2) { return false; }
        }
        try { inputStream.close(); } catch (IOException ignored) {}
        return true;
    }

    @Keep
    public void vibrate(double seconds) {
        if (vibrator != null) {
            long duration = (long)(seconds * 1000.);
            if (android.os.Build.VERSION.SDK_INT >= 26)
                vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
            else
                vibrator.vibrate(duration);
        }
    }

    @Keep
    public boolean hasBackgroundMusic() {
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        return am.isMusicActive();
    }

    @Keep
    public String[] buildFileTree() {
        HashMap<String, Boolean> map = buildFileTree(getAssets(), "", new HashMap<>());
        ArrayList<String> result = new ArrayList<>();
        for (Map.Entry<String, Boolean> data : map.entrySet())
            result.add((data.getValue() ? "d" : "f") + data.getKey());
        String[] r = new String[result.size()];
        result.toArray(r);
        return r;
    }

    @Keep
    public float getDPIScale() {
        return getResources().getDisplayMetrics().density;
    }

    @Keep
    public Rect getSafeArea() {
        Rect rect = null;
        if (android.os.Build.VERSION.SDK_INT >= 28) {
            DisplayCutout cutout = getWindow().getDecorView().getRootWindowInsets().getDisplayCutout();
            if (cutout != null) {
                rect = new Rect();
                rect.set(cutout.getSafeInsetLeft(), cutout.getSafeInsetTop(),
                         cutout.getSafeInsetRight(), cutout.getSafeInsetBottom());
            }
        }
        return rect;
    }

    @Keep
    public String getCRequirePath() {
        ApplicationInfo info = getApplicationInfo();
        if (isNativeLibsExtracted())
            return info.nativeLibraryDir + "/?.so";
        String abi = android.os.Build.SUPPORTED_ABIS[0];
        return info.sourceDir + "!/lib/" + abi + "/?.so";
    }

    @Keep
    public void setImmersiveMode(boolean enable) {
        if (android.os.Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams attr = getWindow().getAttributes();
            attr.layoutInDisplayCutoutMode = enable
                ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
        }
        shortEdgesMode = enable;
    }

    @Keep public boolean getImmersiveMode() { return shortEdgesMode; }

    @Keep
    public boolean hasRecordAudioPermission() {
        return ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
               == PackageManager.PERMISSION_GRANTED;
    }

    @Keep
    public void requestRecordAudioPermission() {
        if (hasRecordAudioPermission()) return;
        ActivityCompat.requestPermissions(this,
            new String[]{Manifest.permission.RECORD_AUDIO}, RECORD_AUDIO_REQUEST_CODE);
        synchronized (recordAudioRequestDummy) {
            try { recordAudioRequestDummy.wait(); }
            catch (InterruptedException e) { Log.d(TAG, "mic wait interrupted", e); }
        }
    }

    public int getAudioSMP() {
        int smp = 256;
        AudioManager a = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (a != null) {
            int b = Integer.parseInt(a.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER));
            smp = b > 0 ? b : smp;
        }
        return smp;
    }

    public int getAudioFreq() {
        int freq = 44100;
        AudioManager a = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (a != null) {
            int b = Integer.parseInt(a.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE));
            freq = b > 0 ? b : freq;
        }
        return freq;
    }

    public boolean isNativeLibsExtracted() {
        return (getApplicationInfo().flags & ApplicationInfo.FLAG_EXTRACT_NATIVE_LIBS) != 0;
    }

    public void sendUriAsDroppedFile(Uri uri) {
        SDLActivity.onNativeDropFile(uri.toString());
    }

    private void handleIntent(Intent intent, boolean onCreate) {
        Uri game = intent.getData();
        if (game == null) return;
        if (onCreate) {
            if (isFused) delayedUri = game;
            else processOpenGame(game);
        } else {
            sendUriAsDroppedFile(game);
        }
    }

    private HashMap<String, Boolean> buildFileTree(AssetManager am, String dir, HashMap<String, Boolean> map) {
        String stripped = dir.endsWith("/") ? dir.substring(0, dir.length() - 1) : dir;
        try {
            InputStream test = am.open(stripped);
            test.close();
            map.put(stripped, false);
        } catch (FileNotFoundException e) {
            String[] list = null;
            try { list = am.list(stripped); } catch (IOException e2) { Log.e(TAG, stripped, e2); }
            map.put(dir, true);
            if (!stripped.equals(dir)) map.put(stripped, true);
            if (list != null)
                for (String path : list) buildFileTree(am, dir + path + "/", map);
        } catch (IOException e) { Log.e(TAG, dir, e); }
        return map;
    }

    private void processOpenGame(Uri game) {
        String scheme = game.getScheme();
        String path   = game.getPath();
        if (scheme != null) {
            if (scheme.equals("content"))   args = new String[]{game.toString()};
            else if (scheme.equals("file")) args = new String[]{path};
        }
    }
}
