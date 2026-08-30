import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.akash.skystream"
    compileSdk = rootProject.extra["projectCompileSdk"] as Int
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.akash.skystream"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = rootProject.extra["projectTargetSdk"] as Int
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = if (keystoreProperties.getProperty("storeFile") != null) file(keystoreProperties.getProperty("storeFile")) else null
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Require a real signing keystore for release. Falling back to
            // the debug key would silently ship an unsigned-for-Play APK
            // (audit H13). For CI/local debug-without-keystore use
            // `flutter run --debug` or `flutter build apk --debug`.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Build still runs (so `flutter build apk --release` works
                // during local exploration without a key.properties) but the
                // resulting APK is debug-signed — never publish it.
                println("WARN: Release build is using DEBUG signing — " +
                        "key.properties not found. This APK MUST NOT be " +
                        "distributed publicly.")
                signingConfig = signingConfigs.getByName("debug")
            }

            // Code & resource shrinking (audit B8). Skip the bundled
            // proguard-android-optimize.txt rules and rely on the
            // Flutter-provided rules plus our own proguard-rules.pro for
            // plugin-specific keep rules.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}


flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.tvprovider:tvprovider:1.0.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
