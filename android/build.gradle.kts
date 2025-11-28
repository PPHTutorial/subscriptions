buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        //classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Fix namespace issues for packages that don't specify it
// Note: The telephony package (0.2.0) is discontinued and missing namespace
// Manual fix required: Edit %USERPROFILE%\.pub-cache\hosted\pub.dev\telephony-0.2.0\android\build.gradle
// Add: namespace = "com.shounakmulay.telephony" in the android block
// See TELEPHONY_FIX.md for details

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
