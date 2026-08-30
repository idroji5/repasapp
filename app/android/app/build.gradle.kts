import java.util.Properties
import java.io.FileInputStream

// Credenciales de firma. Viven fuera del repositorio: sin este fichero la app
// se compila igual, pero firmada con la clave de depuración (sirve para
// desarrollar, no para repartir).
val propiedadesFirma = Properties()
val ficheroFirma = rootProject.file("key.properties")
if (ficheroFirma.exists()) {
    propiedadesFirma.load(FileInputStream(ficheroFirma))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "es.repasapp.repasapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "es.repasapp.repasapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit y speech_to_text necesitan 21 como mínimo.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (propiedadesFirma.getProperty("storeFile") != null) {
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
                storeFile = file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (propiedadesFirma.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                // Sin credenciales se firma con la de depuración, para que
                // `flutter run --release` siga funcionando en cualquier clon.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
