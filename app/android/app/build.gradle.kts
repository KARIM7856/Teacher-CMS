import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties (gitignored) and
// point at keystores/teacher-cms-upload.jks. Absent on machines that only build
// debug (e.g. CI without secrets), in which case the release build falls back to
// debug signing rather than failing — a debug-signed artifact is obviously not
// uploadable to Play, which is the point.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.teachercms.student"

    // Pinned rather than inherited from `flutter.*` so a Flutter SDK upgrade can
    // never silently move the SDK levels an already-published build was tested
    // against. Google Play requires new releases to target a recent API level —
    // re-check the current floor before each submission and bump targetSdk here.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PERMANENT: the Play Store identity of this app. It can never be changed
        // after the first upload — a new value would be a different app listing.
        applicationId = "com.teachercms.student"
        minSdk = 24
        targetSdk = 36
        // Both come from pubspec.yaml's `version: <name>+<code>`; bump it there.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found — signing release with the DEBUG key. This artifact cannot be uploaded to Google Play.")
                signingConfigs.getByName("debug")
            }
            // Code shrinking (R8) and resource shrinking are both switched on by
            // the Flutter Gradle plugin for release builds — do not set them here.
        }
    }

    // Play delivers only the device's language when language splits are on. This
    // app is Arabic regardless of the device language, so keep every localized
    // resource in the base artifact rather than letting Play strip them.
    bundle {
        language {
            enableSplit = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
