plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

fun loadProperties(filename: String): Map<String, String> {
    val properties = mutableMapOf<String, String>()
    val file = rootProject.file(filename)
    if (file.exists()) {
        file.reader().use { reader ->
            reader.buffered().forEachLine { line ->
                if (!line.startsWith("#") && line.contains("=")) {
                    val (key, value) = line.split("=", limit = 2)
                    properties[key.trim()] = value.trim()
                }
            }
        }
    }
    return properties
}

android {
    namespace = "com.tsubuzaki.djdxgo"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.tsubuzaki.djdxgo"
        minSdk = 26
        targetSdk = 37
        versionCode = System.getenv("VERSION_CODE")?.toIntOrNull() ?: 1
        versionName = "1.0"
    }

    signingConfigs {
        create("release") {
            val localProperties = loadProperties("local.properties")
            storeFile = localProperties["signing.storeFile"]?.let { file(it) }
            storePassword = localProperties["signing.storePassword"]
            keyAlias = localProperties["signing.keyAlias"]
            keyPassword = localProperties["signing.keyPassword"]
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
        }
        release {
            isDebuggable = false
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // Kotlin & Coroutines
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)

    // AndroidX Core
    implementation(libs.core.ktx)
    implementation(libs.lifecycle.runtime.ktx)
    implementation(libs.lifecycle.viewmodel.compose)

    // DataStore
    implementation(libs.datastore.preferences)

    // WebView
    implementation(libs.webkit)

    // HTML parsing
    implementation(libs.jsoup)

    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // Compose
    implementation(libs.activity.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.material3)
    implementation(libs.navigation.compose)
}
