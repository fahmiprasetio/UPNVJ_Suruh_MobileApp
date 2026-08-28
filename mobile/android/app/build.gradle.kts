import java.io.FileInputStream
import java.util.Properties

// Berkas ini tidak ikut di repositori, lihat android/key.properties.contoh untuk
// bentuknya. Tanpa berkas ini build rilis sengaja dibiarkan tidak tertanda tangan.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.upnvjsuruh.upnvj_suruh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.upnvjsuruh.upnvj_suruh"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sebelumnya rilis ditandatangani debug keystore bawaan template Flutter.
            // Kunci itu publik dan sama di setiap mesin, jadi siapa pun bisa merakit APK
            // yang lolos verifikasi tanda tangan aplikasi ini.
            //
            // Kalau key.properties belum ada, hasilnya build rilis yang tidak
            // tertandatangani dan gagal dipasang. Itu memang yang diinginkan: gagal
            // dengan berisik lebih baik daripada diam-diam mengirim APK bertanda tangan
            // debug ke dosen atau mitra.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
