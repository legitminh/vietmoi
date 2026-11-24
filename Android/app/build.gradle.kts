import java.util.Properties

plugins { id("com.android.application") }

val appRelease = Properties().apply { rootProject.projectDir.parentFile.resolve("Design/version.properties").inputStream().use { load(it) } }

android {
    namespace = "com.minh.sieuviet.android"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.minh.sieuviet.android"
        minSdk = 29
        targetSdk = 36
        versionCode = appRelease.getProperty("build").toInt()
        versionName = appRelease.getProperty("version")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    sourceSets.getByName("main").jniLibs.srcDir(rootProject.projectDir.parentFile.resolve("build/android-native"))
    // The shared UI (scripts/build-web.py) ships as assets/WebApp.
    sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("shared-ui"))
    packaging { jniLibs { useLegacyPackaging = false } }
}

val buildSwift by tasks.registering(Exec::class) {
    workingDir(rootProject.projectDir.parentFile)
    commandLine("python3", "scripts/build-android-native.py")
}
val copySharedUI by tasks.registering(Sync::class) {
    from(rootProject.projectDir.parentFile.resolve("Resources/WebApp"))
    into(layout.buildDirectory.dir("shared-ui/WebApp"))
}
tasks.named("preBuild").configure { dependsOn(buildSwift, copySharedUI) }

dependencies {
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
