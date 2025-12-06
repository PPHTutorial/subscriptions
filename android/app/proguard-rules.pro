# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Gson specific classes
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Dio
-keep class dio.** { *; }
-dontwarn dio.**

# Hive
-keep class io.flutter.plugins.hive.** { *; }
-dontwarn io.flutter.plugins.hive.**

# Google Mobile Ads (removed - not used in pro version)
# Suppress warnings for missing AdMob classes
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# Google Play Services (needed for in_app_review)
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# In-App Purchase (removed - not used in pro version)
# Suppress warnings for missing billing classes
-dontwarn com.android.billingclient.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
}

# Kotlin Coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.flow.internal.**
-keep class kotlinx.coroutines.** { *; }

# Riverpod
-keep class io.flutter.plugins.riverpod.** { *; }
-dontwarn io.flutter.plugins.riverpod.**

# HTML Parser
-keep class org.jsoup.** { *; }
-dontwarn org.jsoup.**

# Image processing
-keep class com.googlecode.pngtastic.** { *; }
-keep class image.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# Flutter deferred components (Play Core - optional)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }

# General Flutter plugin rules
-keep class * extends io.flutter.plugin.common.PluginRegistry
-keep class * implements io.flutter.plugin.common.PluginRegistry
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google ML Kit Text Recognition
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep all native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep generic signatures
-keepattributes Signature

# Keep custom model classes (for Hive, JSON serialization, etc.)
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <methods>;
}

# Prevent obfuscation of classes used in native code
-keepclasseswithmembers class * {
    native <methods>;
}

