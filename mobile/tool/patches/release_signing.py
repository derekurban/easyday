# Release signing from android/key.properties (ignored by git; the keystore lives outside the repo), falling back to
# the debug key when the file is absent so a fresh checkout still builds. Plus what the in-app updater needs on the
# Android side: the install permission and a FileProvider for the downloaded APK.
import os
p='android/app/build.gradle.kts'
s=open(p,encoding='utf-8').read()
old="""plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
"""
new="""import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties names the keystore (kept outside the repo). Without it, the debug key.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
"""
assert old in s; s=s.replace(old,new,1)
old="""    buildTypes {
        release {
            // Still signed with the debug keys: a release keystore is not set up yet.
            signingConfig = signingConfigs.getByName("debug")
        }
    }"""
new="""    signingConfigs {
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
        release {
            signingConfig = if (keyProps.containsKey("storeFile")) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }"""
assert old in s; s=s.replace(old,new,1)
old="""dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}"""
new="""dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.13.1")
}"""
assert old in s; s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

p='android/app/src/main/AndroidManifest.xml'
s=open(p,encoding='utf-8').read()
old="""    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
"""
new="""    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
"""
assert old in s; s=s.replace(old,new,1)
old="""        <!-- Don't delete the meta-data below."""
new="""        <!-- Lets the package installer read an APK the app downloaded into its cache (the in-app update). -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.files"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths"/>
        </provider>

        <!-- Don't delete the meta-data below."""
assert old in s; s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

os.makedirs('android/app/src/main/res/xml', exist_ok=True)
open('android/app/src/main/res/xml/file_paths.xml','w',encoding='utf-8').write('''<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="updates" path="updates/"/>
</paths>
''')
print('ok')
