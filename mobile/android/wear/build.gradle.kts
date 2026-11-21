import java.util.Properties

// Easyday on the wrist (docs/app/WATCH.md): a Wear OS app that follows the workout under way on the phone, sends its
// taps back, and records the heart rate. It carries the phone app's own ids per flavour and build type, and is signed
// with the same key: the Wear data layer only connects an app to its twin with the same id and signature.
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// The version follows pubspec.yaml, like the phone's; CI passes the build's own (-PwearVersionName, -PwearVersionCode).
val pubspec = rootProject.file("../pubspec.yaml").readLines().first { it.startsWith("version:") }.substringAfter(":").trim()
val wearVersionName = providers.gradleProperty("wearVersionName").getOrElse(pubspec.substringBefore("+"))
val wearVersionCode = providers.gradleProperty("wearVersionCode").getOrElse(pubspec.substringAfter("+", "1")).toInt()

android {
    namespace = "app.easyday.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.easyday"
        minSdk = 30        // Wear OS 3, the Galaxy Watch 4's first
        targetSdk = 36
        versionCode = wearVersionCode
        versionName = wearVersionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Easyday")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Easyday Staging")
        }
    }

    signingConfigs {
        if (keyProps.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Easyday Dev")
        }
        release {
            isMinifyEnabled = false
            signingConfig = if (keyProps.containsKey("storeFile")) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.10.1")
    // Play services pulls in an old Fragment, which the permission request (ActivityResult) cannot run with
    implementation("androidx.fragment:fragment:1.8.5")
    implementation(platform("androidx.compose:compose-bom:2025.06.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.wear.compose:compose-foundation:1.5.0")
    implementation("androidx.wear.compose:compose-material3:1.5.0")
    implementation("androidx.wear:wear-ongoing:1.0.0")
    implementation("androidx.health:health-services-client:1.1.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
}
