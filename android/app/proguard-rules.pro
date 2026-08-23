# SkyStream release ProGuard / R8 rules.
#
# Flutter already ships a baseline rules file (`flutter.txt`) applied
# automatically by the Flutter Gradle plugin. The rules below cover the
# common offenders for the plugins this app uses — packages that rely on
# reflection (and that R8 would otherwise strip / rename).
#
# Pattern: prefer scoped `-keep class com.example.thing.**` over blanket
# `-keepattributes Signature` so we don't undo R8's size win.

# ─────────────────────────────────────────────────────────────────────────
# Flutter core
# ─────────────────────────────────────────────────────────────────────────
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ─────────────────────────────────────────────────────────────────────────
# media_kit — uses JNI via libmpv; preserve the JNI bridge classes.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# ─────────────────────────────────────────────────────────────────────────
# flutter_inappwebview — reflection for JS<->Dart bridges + WebView
# clients/chrome client subclasses.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.pichillilorenzo.** { *; }
-keepclassmembers class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * extends android.webkit.WebChromeClient { *; }
-dontwarn com.pichillilorenzo.**

# ─────────────────────────────────────────────────────────────────────────
# flutter_js_ng (forked QuickJS bindings) — JNI surface for the JS engine.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.abedalkareem.flutter_js.** { *; }
-keep class com.appcheap.flutter_js_ng.** { *; }
-keep class io.alicorn.android.sdk.translator.** { *; }
-dontwarn com.abedalkareem.flutter_js.**
-dontwarn com.appcheap.flutter_js_ng.**

# ─────────────────────────────────────────────────────────────────────────
# background_downloader uses sqflite + WorkManager — keep both.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.bbflight.background_downloader.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ─────────────────────────────────────────────────────────────────────────
# Hive — reflection on TypeAdapter subclasses (only matters if we register
# custom adapters; SkyStream uses dynamic boxes, but kept defensively).
# ─────────────────────────────────────────────────────────────────────────
-keep class * extends hive.HiveObject { *; }
-keepclassmembers class * extends hive.TypeAdapter {
    public <init>(...);
}

# ─────────────────────────────────────────────────────────────────────────
# pointycastle / encrypt — uses reflection on cipher class names.
# ─────────────────────────────────────────────────────────────────────────
-keep class org.bouncycastle.** { *; }
-keep class com.pointycastle.** { *; }
-dontwarn org.bouncycastle.**

# ─────────────────────────────────────────────────────────────────────────
# permission_handler — reflection on AndroidX activity-result classes.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─────────────────────────────────────────────────────────────────────────
# Misc plugins that bridge via reflection.
# ─────────────────────────────────────────────────────────────────────────
-keep class com.ryanheise.audio_session.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# ─────────────────────────────────────────────────────────────────────────
# Strip BuildConfig / R fields R8 already knows about; reduces APK size.
# ─────────────────────────────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
}

# ─────────────────────────────────────────────────────────────────────────
# Preserve Dart-side @pragma('vm:entry-point') annotated methods invoked
# from native (Flutter engine calls them by name).
# Already handled by the Flutter Gradle plugin; included here for clarity.
# ─────────────────────────────────────────────────────────────────────────
-keep @io.flutter.embedding.android.annotation.* class * { *; }

# ─────────────────────────────────────────────────────────────────────────
# Reflection-based class loading from Talker (debug logger).
# ─────────────────────────────────────────────────────────────────────────
-dontwarn com.example.talker.**

# ─────────────────────────────────────────────────────────────────────────
# Quiet noisy warnings from optional packages.
# ─────────────────────────────────────────────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

# ─────────────────────────────────────────────────────────────────────────
# androidx.window optional runtime APIs.
#
# androidx.window ships compile-time references to OEM-provided extension and
# sidecar classes (androidx.window.extensions.*, androidx.window.sidecar.*)
# that only exist on foldables and large-screen devices that implement them.
# They are absent from the SDK, so R8 fails the release build outright with
# "Missing class androidx.window.extensions.WindowExtensions" and ~12 similar.
# androidx.window reflects on them and degrades gracefully when absent, so
# these are safe to leave unresolved.
#
# Verified pre-existing: a release build with vlc_player removed produces the
# identical failure, so this is not caused by any recent dependency.
# ─────────────────────────────────────────────────────────────────────────
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
