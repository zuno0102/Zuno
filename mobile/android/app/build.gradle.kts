import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release signing key, kept out of the repository.
//
// android/key.properties and the .jks it points at are both gitignored, because whoever holds
// them can publish an update that Android will install over this app without question. When the
// file is absent — a fresh clone, or CI without the secret — the release build falls back to the
// debug key below, so `flutter run --release` still works for whoever is just trying the app.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")

// The --dart-define values, which Flutter hands Gradle base64-encoded and comma-separated.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.associate {
            val pair = String(Base64.getDecoder().decode(it))
            pair.substringBefore("=") to pair.substringAfter("=", "")
        }
        ?: emptyMap()

android {
    namespace = "com.zuno.zuno"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications, which uses java.time to schedule.
        //
        // Desugaring back-ports those APIs to the older Android versions this app still supports.
        // The alternative would be raising minSdk, which would drop real phones — the cheaper
        // phones this app's workers are most likely to be carrying.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zuno.zuno"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The Google Maps key, taken from the same `--dart-define=GOOGLE_MAPS_KEY=...` the Dart
        // side reads, so one build flag switches both on. Empty when not given: the app then draws
        // its free maps and never creates a Google map that would need the key.
        manifestPlaceholders["googleMapsKey"] = dartDefines["GOOGLE_MAPS_KEY"] ?: ""
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real key when one is configured. An APK signed with the debug key
            // cannot be published, and worse, cannot later be replaced by a properly signed one:
            // Android refuses an update whose signature differs from what is installed.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Named even though shrinking is off today, so that switching it on later cannot
            // quietly strip Razorpay and break paying a crew in release builds only.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // The back-ported library the desugaring above rewrites calls into. Pinned rather than
    // floating: a build that changes this on its own is a build that can break on a machine that
    // happened to resolve a different version.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
