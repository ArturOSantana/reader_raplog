import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Lê android/key.properties (gerado pelo CI ou criado localmente para release)
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties().also { props ->
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { props.load(it) }
}

android {
    namespace = "com.readlog.readlog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            // Usa keystore de release quando key.properties existir; cai para debug caso contrário
            if (keyPropsFile.exists()) {
                storeFile     = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias      = keyProps["keyAlias"] as String
                keyPassword   = keyProps["keyPassword"] as String
            } else {
                // Desenvolvimento local sem keystore configurada — usa debug key
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }

    defaultConfig {
        applicationId = "com.readlog.readlog"
        // minSdk fixado em 23 (Android 6.0, Marshmallow).
        // Piso real ditado pelos plugins:
        //   - mobile_scanner 7.x: minSdk 23
        //   - flutter_local_notifications 18.x: minSdk 19
        //   - share_plus 13.x / home_widget 0.9.x: minSdk 16/21
        // flutter.minSdkVersion no Flutter 3.44+ retorna 24, o que bloquearia
        // dispositivos Android 6 desnecessariamente — fixamos em 23 aqui.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // proguardFiles no defaultConfig é ACUMULATIVO — nunca sobrescrito por buildTypes.
        // Garante que as regras chegam ao R8 independentemente da ordem de avaliação do plugin.
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            // Suffix garante que debug e release coexistam no mesmo device sem
            // conflito de certificado — são tratados como apps distintos pelo Android.
            applicationIdSuffix = ".debug"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
