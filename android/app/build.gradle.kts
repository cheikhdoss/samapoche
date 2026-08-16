import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "sn.samapoche.samapoche"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "sn.samapoche.samapoche"
        // Vous pouvez mettre à jour les valeurs suivantes selon vos besoins.
        // Pour plus d'informations : https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Flavors d'environnement : dev / staging / prod.
    // Chaque flavor porte un applicationId suffixé (installation côte à côte
    // possible) et un nom d'application dédié. Le nom d'app est injecté via
    // resValue et lu par AndroidManifest (android:label="@string/app_name").
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "SamaPoche Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "SamaPoche Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "SamaPoche")
        }
    }

    // Signature release : identifiants lus depuis android/key.properties
    // (écrit par .github/actions/android-signing en CI à partir des secrets ;
    // jamais committé). Sans keystore (développement local, PR sans secrets),
    // le build retombe sur la clé debug : les artefacts ne sont alors PAS
    // signés pour la production.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }
    val hasReleaseKeystore =
        keystorePropertiesFile.exists() &&
            keystoreProperties.getProperty("storeFile") != null

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // TODO: Replace with a real signing config for release builds.
                // Signing with the debug keys so `flutter run --release` works.
                signingConfig = signingConfigs.getByName("debug")
            }
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
