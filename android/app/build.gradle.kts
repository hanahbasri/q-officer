plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.15.0"))

    // ✅ Firebase Analytics (tanpa versi, karena pakai BoM)
    implementation("com.google.firebase:firebase-analytics")

    // ✅ FIX: Desugar libs harus pakai `coreLibraryDesugaring`
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") // ✅
}

android {
    namespace = "com.example.q_officer_barantin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true// ✅ pakai `= true`
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.q_officer_barantin"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
