plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.butterscotch.butterscotch"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.butterscotch.butterscotch"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.02.00"))

    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation("io.coil-kt:coil-compose:2.7.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
}

tasks.register("installRunLogs") {
    dependsOn("installDebug")

    doLast {
        val adb = "${System.getProperty("user.home")}/Library/Android/sdk/platform-tools/adb"

        exec {
            commandLine(adb, "logcat", "-c")
        }

        exec {
            commandLine(
                adb,
                "shell",
                "am",
                "force-stop",
                "com.butterscotch.butterscotch"
            )
        }

        exec {
            commandLine(
                adb,
                "shell",
                "am",
                "start",
                "-n",
                "com.butterscotch.butterscotch/.MainActivity"
            )
        }

        exec {
            commandLine(adb, "logcat", "-s", "Butterscotch")
        }
    }
}