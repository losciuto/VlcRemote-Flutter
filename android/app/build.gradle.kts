import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chiave di firma della release.
//
// Va generata una volta e tenuta FUORI dal repository:
//
//   keytool -genkey -v -keystore ~/keys/vlcremote-release.jks \
//           -keyalg RSA -keysize 2048 -validity 10000 -alias vlcremote
//
// Poi in android/key.properties (anch'esso fuori dal repository, vedi .gitignore):
//
//   storePassword=...
//   keyPassword=...
//   keyAlias=vlcremote
//   storeFile=/percorso/assoluto/vlcremote-release.jks
//
// Senza questo file si continua a firmare con la chiave di debug, che e' pubblica
// e identica su ogni installazione al mondo: chiunque potrebbe firmare un APK
// che sostituisce questa app. Il gradle stampa un avviso perche' non passi
// inosservato.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else {
    logger.warn(
        "AVVISO: android/key.properties assente, la release verra' firmata con la " +
            "chiave di debug. Non distribuire questo APK: chiunque puo' firmare " +
            "un aggiornamento sostitutivo. Vedi AGENTS.md."
    )
}

android {
    namespace = "com.losciuto.vlc_remote_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.losciuto.vlc_remote_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
