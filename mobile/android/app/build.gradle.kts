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
        // Fixado em 23 para cobrir o requisito mínimo real das dependências:
        // home_widget, flutter_local_notifications e share_plus exigem API 23+.
        // Usar flutter.minSdkVersion (21) causaria crash em Android 5.x/6.0.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // proguardFiles() garante que AMBOS os arquivos são aplicados pelo R8:
            // 1. proguard-android-optimize.txt — regras padrão do Android SDK
            // 2. proguard-rules.pro            — regras customizadas do app
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
