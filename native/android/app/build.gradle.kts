plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    // Needs app/google-services.json (Firebase console, not committed).
    id("com.google.gms.google-services")
}

android {
    namespace = "app.cinquante.mobile"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.cinquante.mobile"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        // The Rails app. Must match APP_HOST on the server and the App Links host.
        buildConfigField("String", "BASE_URL", "\"https://cinquante.app\"")
    }

    buildTypes {
        debug {
            // The emulator reaches the Mac's `bin/dev` at 10.0.2.2.
            buildConfigField("String", "BASE_URL", "\"http://10.0.2.2:3000\"")
        }
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // signingConfig: see native/README.md (Play App Signing + upload key).
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Hotwire Native Android (https://github.com/hotwired/hotwire-native-android)
    implementation("dev.hotwire:core:1.2.0")
    implementation("dev.hotwire:navigation-fragments:1.2.0")

    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")

    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}
