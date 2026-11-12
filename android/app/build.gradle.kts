plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.google.services)
}

android {
    namespace = "com.dycdyp.youniya"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.dycdyp.youniya"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
        // Meta (Facebook) App ID for Instagram Stories; empty hides the button, as on iOS (INSTAGRAM_APP_ID).
        buildConfigField("String", "INSTAGRAM_APP_ID", "\"\"")
    }

    // Play upload key (Play App Signing re-signs for users). The path and passwords live in
    // ~/.gradle/gradle.properties, outside the repo; without them a release build stays unsigned.
    val uploadStore = project.findProperty("YOUNIYA_UPLOAD_STORE") as String?
    signingConfigs {
        if (uploadStore != null) {
            create("upload") {
                storeFile = file(uploadStore)
                storePassword = project.findProperty("YOUNIYA_UPLOAD_STORE_PASSWORD") as String?
                keyAlias = project.findProperty("YOUNIYA_UPLOAD_ALIAS") as String?
                keyPassword = project.findProperty("YOUNIYA_UPLOAD_KEY_PASSWORD") as String?
            }
        }
    }

    buildTypes {
        debug {
            // Home-desktop dev server over Tailscale (the same one the iOS debug build uses).
            // `-PapiBaseUrl=https://youniya-api.dycdyp.com` points a debug build at production
            // (e.g. to try the real Apple web flow, which the dev server has no Services ID for).
            val apiBaseUrl = (project.findProperty("apiBaseUrl") as String?) ?: "http://100.126.111.107:8000"
            buildConfigField("String", "API_BASE_URL", "\"$apiBaseUrl\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "API_BASE_URL", "\"https://youniya-api.dycdyp.com\"")
            if (uploadStore != null) signingConfig = signingConfigs.getByName("upload")
        }
    }

    // Release code (R8, no debugging) signed with the debug key, against the dev server: for timing on a device.
    buildTypes.create("benchmark") {
        initWith(buildTypes.getByName("release"))
        signingConfig = signingConfigs.getByName("debug")
        matchingFallbacks += listOf("release")
        buildConfigField("String", "API_BASE_URL", "\"http://100.126.111.107:8000\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play)
    implementation(libs.googleid)
    implementation(libs.androidx.browser)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.billing.ktx)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    implementation(libs.okhttp)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
}
