import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.codeink.stsl.subscriptions"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codeink.stsl.subscriptions"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        
        // Include both 32-bit and 64-bit ARM architectures (required by Google Play)
        // Exclude x86_64 to support 16 KB page sizes
        // arm64-v8a (64-bit) is REQUIRED for Google Play 64-bit requirement
        // armeabi-v7a (32-bit) is for older devices
        ndk {
            abiFilters.clear()
            abiFilters.add("armeabi-v7a")  // 32-bit ARM
            abiFilters.add("arm64-v8a")    // 64-bit ARM (REQUIRED)
        }
    }
    
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Exclude x86_64 and x86 to support 16 KB page sizes
            // Also exclude problematic ML Kit library that doesn't support 16KB page sizes
            // This must be done BEFORE signing to avoid invalid signature
            excludes += setOf(
                "lib/x86_64/**",
                "lib/x86/**",
                "**/libbarhopper_v3.so"
            )
        }
    }
    
    splits {
        abi {
            isEnable = false
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties["storeFile"] as String?
                if (storeFilePath != null && storeFilePath.isNotEmpty()) {
                    // Handle both absolute and relative paths
                    val keystoreFile = if (storeFilePath.startsWith("/") || storeFilePath.matches(Regex("^[A-Za-z]:.*"))) {
                        file(storeFilePath)
                    } else {
                        rootProject.file(storeFilePath)
                    }
                    
                    if (keystoreFile.exists()) {
                        keyAlias = keystoreProperties["keyAlias"] as String?
                        keyPassword = keystoreProperties["keyPassword"] as String?
                        storeFile = keystoreFile
                        storePassword = keystoreProperties["storePassword"] as String?
                    } else {
                        println("Warning: Keystore file not found at: ${keystoreFile.absolutePath}")
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists() && 
                                  signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
}


flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}