plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shopease.mobile.shopease_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shopease.mobile.shopease_mobile"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- Ø¥Ø¶Ø§ÙØ© Ø®Ø§ØµÙŠØ© Ø§Ù„Ù€ MultiDex Ø¹Ø´Ø§Ù† Ù…ÙƒØªØ¨Ø§Øª Ø§Ù„Ø¥ÙŠÙ…ÙŠÙ„ ---
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// --- Ø§Ø³ØªØ®Ø¯Ø§Ù… compilerOptions Ø¨Ø¯Ù„Ø§Ù‹ Ù…Ù† kotlinOptions Ø§Ù„Ù…ØªÙ‚Ø§Ø¯Ù…Ø© ---
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

// --- Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ù…ÙƒØªØ¨Ø§Øª Ù‡Ù†Ø§ ÙÙŠ Ù†Ù‡Ø§ÙŠØ© Ø§Ù„Ù…Ù„Ù ---
dependencies {
    implementation("com.sun.mail:android-mail:1.6.2")
    implementation("com.sun.mail:android-activation:1.6.2")
    implementation("androidx.multidex:multidex:2.0.1")
}
