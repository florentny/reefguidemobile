plugins {
    id("com.android.dynamic-feature")
}

android {
    namespace = "org.reefguide.reefmobile.pix1"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    sourceSets {
        named("main") {
            assets.srcDir(
                layout.buildDirectory.dir("intermediates/flutter/release/deferred_assets")
            )
        }
    }
}

dependencies {
    implementation(project(":app"))
}
