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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import com.unity3d.ads.IUnityAdsInitializationListener;
import com.unity3d.ads.IUnityAdsLoadListener;
import com.unity3d.ads.IUnityAdsShowListener;
import com.unity3d.ads.UnityAds;
import com.unity3d.ads.UnityAdsShowOptions;

public class GameActivity extends SDLActivity {

    private static final String TAG        = "GameActivity";
    private static final String ADTAG      = "UnityAdsGame";
    public  static final int RECORD_AUDIO_REQUEST_CODE = 3;

    private static final String GAME_ID    = "6051973";
    private static final String AD_UNIT_ID = "Rewarded_Android";
    private static final boolean TEST_MODE = false;

    // instance ثابت للوصول من Lua
    public static GameActivity instance = null;

    private volatile boolean adLoaded        = false;
    private volatile boolean adRewardGranted = false;
    private volatile boolean adNotAvailable  = false;
    private volatile boolean adIsLoading     = false;

    // مسار ملفات التواصل مع Lua
    private String adCommandFile;
    private String adResultFile;

    protected Vibrator vibrator;
    protected boolean  shortEdgesMode;
    protected final int[] recordAudioRequestDummy = new int[1];
    private Uri      delayedUri = null;
    private String[] args;
    private boolean  isFused;

    private static native void nativeSetDefaultStreamValues(int sampleRate, int framesPerBurst);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "started");
        instance = this;

        // تهيئة مسارات الملفات
        adCommandFile = getFilesDir().getAbsolutePath() + "/ad_command.txt";
        adResultFile  = getFilesDir().getAbsolutePath() + "/ad_result.txt";

        // مسح الملفات القديمة
        new java.io.File(adCommandFile).delete();
        new java.io.File(adResultFile).delete();

        // مراقبة أوامر Lua كل 500ms
        android.os.Handler handler = new android.os.Handler();
        Runnable commandChecker = new Runnable() {
            @Override
            public void run() {
                checkLuaCommand();
                handler.postDelayed(this, 300);
            }
        };
        handler.postDelayed(commandChecker, 1000);

        isFused = hasEmbeddedGame();
        args    = new String[0];

        // تهيئة Unity Ads
        UnityAds.initialize(this, GAME_ID, TEST_MODE, new IUnityAdsInitializationListener() {
            @Override
            public void onInitializationComplete() {
                Log.d(ADTAG, "Unity Ads initialized");
                loadRewardedAd();
            }

            @Override
            public void onInitializationFailed(UnityAds.UnityAdsInitializationError error, String message) {
                Log.d(ADTAG, "Unity Ads init failed: " + message);
            }
        });

        if (checkCallingOrSelfPermission(Manifest.permission.VIBRATE)
                == PackageManager.PERMISSION_GRANTED) {
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
            attr.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
            shortEdgesMode = false;
        }

        if (delayedUri != null) {
            sendUriAsDroppedFile(delayedUri);
            delayedUri = null;
        }
    }

    // =====================================================
    // قراءة أوامر Lua
    // =====================================================
    private void checkLuaCommand() {
        java.io.File cmdFile = new java.io.File(adCommandFile);
        if (!cmdFile.exists()) return;
        try {
            java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(cmdFile));
            String cmd = br.readLine();
            br.close();
            cmdFile.delete();
            if ("show".equals(cmd)) {
                Log.d(ADTAG, "Lua requested: show ad");
                showRewardedAd();
            } else if ("load".equals(cmd)) {
                Log.d(ADTAG, "Lua requested: load ad");
                loadRewardedAd();
            }
        } catch (Exception e) {
            Log.e(ADTAG, "checkLuaCommand error: " + e.getMessage());
        }
    }

    private void writeResult(String result) {
        try {
            java.io.FileWriter fw = new java.io.FileWriter(adResultFile);
            fw.write(result);
            fw.close();
        } catch (Exception e) {
            Log.e(ADTAG, "writeResult error: " + e.getMessage());
        }
    }

    // =====================================================
    // تحميل الإعلان
    // =====================================================
    @Keep
    public void loadRewardedAd() {
        if (adIsLoading || adLoaded) return;
        adIsLoading = true;

        UnityAds.load(AD_UNIT_ID, new IUnityAdsLoadListener() {
            @Override
            public void onUnityAdsAdLoaded(String placementId) {
                Log.d(ADTAG, "Ad loaded: " + placementId);
                adLoaded     = true;
                adIsLoading  = false;
                adNotAvailable = false;
            }

            @Override
            public void onUnityAdsFailedToLoad(String placementId,
                    UnityAds.UnityAdsLoadError error, String message) {
                Log.d(ADTAG, "Ad failed to load: " + message);
                adLoaded     = false;
                adIsLoading  = false;
                adNotAvailable = true;
            }
        });
    }

    // =====================================================
    // عرض الإعلان
    // =====================================================
    @Keep
    public void showRewardedAd() {
        if (!adLoaded) {
            adNotAvailable = true;
            loadRewardedAd();
            return;
        }

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                UnityAds.show(GameActivity.this, AD_UNIT_ID, new UnityAdsShowOptions(),
                    new IUnityAdsShowListener() {
                        @Override
                        public void onUnityAdsShowStart(String placementId) {
                            Log.d(ADTAG, "Ad started");
                        }

                        @Override
                        public void onUnityAdsShowClick(String placementId) {}

                        @Override
                        public void onUnityAdsShowComplete(String placementId,
                                UnityAds.UnityAdsShowCompletionState state) {
                            if (state == UnityAds.UnityAdsShowCompletionState.COMPLETED) {
                                Log.d(ADTAG, "Ad completed - reward granted");
                                adRewardGranted = true;
                                writeResult("reward");
                            } else {
                                Log.d(ADTAG, "Ad skipped");
                                writeResult("skipped");
                            }
                            adLoaded = false;
                            loadRewardedAd();
                        }

                        @Override
                        public void onUnityAdsShowFailure(String placementId,
                                UnityAds.UnityAdsShowError error, String message) {
                            Log.d(ADTAG, "Ad show failed: " + message);
                            adNotAvailable = true;
                            adLoaded       = false;
                            writeResult("failed");
                            loadRewardedAd();
                        }
                    });
            }
        });
    }

    // =====================================================
    // Lua تسأل: هل تمت المكافأة؟
    // =====================================================
    @Keep
    public boolean pollAdReward() {
        if (adRewardGranted) {
            adRewardGranted = false;
            return true;
        }
        return false;
    }

    // =====================================================
    // Lua تسأل: هل الإعلان غير متاح؟
    // =====================================================
    @Keep
    public boolean pollAdNotAvailable() {
        if (adNotAvailable) {
            adNotAvailable = false;
            return true;
        }
        return false;
    }

    // =====================================================
    // هل الإعلان جاهز؟
    // =====================================================
    @Keep
    public boolean isAdReady() {
        return adLoaded;
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
    public void onRequestPermissionsResult(int requestCode,
                                           String[] permissions,
                                           int[] grantResults) {
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
        try {
            inputStream = am.open("main.lua");
        } catch (IOException e) {
            try {
                inputStream = am.open("game.love");
            } catch (IOException e2) {
                return false;
            }
        }
        try { inputStream.close(); } catch (IOException ignored) {}
        return true;
    }

    @Keep
    public void vibrate(double seconds) {
        if (vibrator != null) {
            long duration = (long)(seconds * 1000.);
            if (android.os.Build.VERSION.SDK_INT >= 26) {
                vibrator.vibrate(VibrationEffect.createOneShot(
                    duration, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                vibrator.vibrate(duration);
            }
        }
    }

    @Keep
    public boolean hasBackgroundMusic() {
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        return am.isMusicActive();
    }

    @Keep
    public String[] buildFileTree() {
        HashMap<String, Boolean> map = buildFileTree(
            getAssets(), "", new HashMap<String, Boolean>());
        ArrayList<String> result = new ArrayList<String>();
        for (Map.Entry<String, Boolean> data : map.entrySet()) {
            result.add((data.getValue() ? "d" : "f") + data.getKey());
        }
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
            DisplayCutout cutout = getWindow().getDecorView()
                .getRootWindowInsets().getDisplayCutout();
            if (cutout != null) {
                rect = new Rect();
                rect.set(cutout.getSafeInsetLeft(),  cutout.getSafeInsetTop(),
                         cutout.getSafeInsetRight(), cutout.getSafeInsetBottom());
            }
        }
        return rect;
    }

    @Keep
    public String getCRequirePath() {
        ApplicationInfo info = getApplicationInfo();
        if (isNativeLibsExtracted()) {
            return info.nativeLibraryDir + "/?.so";
        }
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

    @Keep
    public boolean getImmersiveMode() { return shortEdgesMode; }

    @Keep
    public boolean hasRecordAudioPermission() {
        return ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
               == PackageManager.PERMISSION_GRANTED;
    }

    @Keep
    public void requestRecordAudioPermission() {
        if (hasRecordAudioPermission()) return;
        ActivityCompat.requestPermissions(this,
            new String[]{Manifest.permission.RECORD_AUDIO},
            RECORD_AUDIO_REQUEST_CODE);
        synchronized (recordAudioRequestDummy) {
            try {
                recordAudioRequestDummy.wait();
            } catch (InterruptedException e) {
                Log.d(TAG, "mic wait interrupted", e);
            }
        }
    }

    public int getAudioSMP() {
        int smp = 256;
        AudioManager a = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (a != null) {
            int b = Integer.parseInt(
                a.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER));
            smp = b > 0 ? b : smp;
        }
        return smp;
    }

    public int getAudioFreq() {
        int freq = 44100;
        AudioManager a = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (a != null) {
            int b = Integer.parseInt(
                a.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE));
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

    private HashMap<String, Boolean> buildFileTree(AssetManager am,
                                                    String dir,
                                                    HashMap<String, Boolean> map) {
        String stripped = dir.endsWith("/") ? dir.substring(0, dir.length() - 1) : dir;
        try {
            InputStream test = am.open(stripped);
            test.close();
            map.put(stripped, false);
        } catch (FileNotFoundException e) {
            String[] list = null;
            try {
                list = am.list(stripped);
            } catch (IOException e2) {
                Log.e(TAG, stripped, e2);
            }
            map.put(dir, true);
            if (!stripped.equals(dir)) map.put(stripped, true);
            if (list != null) {
                for (String path : list) {
                    buildFileTree(am, dir + path + "/", map);
                }
            }
        } catch (IOException e) {
            Log.e(TAG, dir, e);
        }
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
