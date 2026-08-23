group = "com.lingjhf.vlc_player"
version = "1.0-SNAPSHOT"

// No `buildscript` block here on purpose.
//
// Upstream pinned AGP 9.0.1 / Kotlin 2.3.20 on its own classpath. A Flutter
// plugin is built as a subproject of the host app, so the host's plugin
// management already supplies both — and a second, different version on the
// plugin's classpath conflicts with it. SkyStream is on AGP 8.13.0 / Kotlin
// 2.2.20 and cannot currently move to 9.0.1: AGP 9 rejects
// `getDefaultProguardFile('proguard-android.txt')`, which
// flutter_inappwebview_android 1.1.3 still uses, and that package has had no
// stable release since 2024-10-02.
//
// Removing the block lets the plugin inherit whatever the host uses, which is
// what every other vendored package here does.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.lingjhf.vlc_player"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        // Was 29 upstream, with no comment and nothing requiring it.
        //
        // Nothing in this plugin needs API 29. libVLC itself declares
        // minSdkVersion 17 (verified in the libvlc-all:3.7.0 AAR manifest), and
        // the only API in this plugin's Kotlin newer than API 17 is
        // android.view.PixelCopy — API 24 — used solely by takeSnapshot. There
        // is not a single @RequiresApi or Build.VERSION guard in the source.
        //
        // 24 matches Flutter's own default minSdkVersion, so hosts inherit it
        // for free. It also matters commercially: 29 excluded Fire OS 7, which
        // is Android 9 / API 28, and that is a large share of Fire TV devices.
        //
        // Going below 24 is possible — it needs a SDK_INT guard around the
        // PixelCopy call in VlcPlayerPlatformView — but is not done here.
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.videolan.android:libvlc-all:3.7.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
