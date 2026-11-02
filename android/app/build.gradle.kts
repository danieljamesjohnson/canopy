plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.danjjohnson.canopy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time APIs that do not
        // exist below API 26. Without this the Android build fails outright at
        // :app:checkDebugAarMetadata — it is not a warning.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.danjjohnson.canopy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // flutter_appauth (Google sign-in, Phase 36) declares a redirect activity
        // whose scheme comes from this placeholder, and the manifest merge FAILS
        // without it -- this broke every Android CI build from 2026-09-28 to
        // 2026-11-02. Android has no Google sign-in (D-36-01: Android and the
        // browser keep the .ics path), so the value only has to be a valid,
        // app-unique scheme; the reversed app id is the conventional choice.
        manifestPlaceholders["appAuthRedirectScheme"] = "com.danjjohnson.canopy"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Supplies the desugared java.time implementation that
    // `isCoreLibraryDesugaringEnabled` above depends on. Both halves are required —
    // enabling the flag without this dependency fails the build with a different error.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
