# ProGuard / R8 keep rules.
#
# R8 shrinks and optimises the Android/Kotlin/plugin layer for release builds.
# Its danger is stripping classes only reached by reflection (Firebase, Gson,
# notification plugins) — those compile fine and then crash ONLY in the release
# build. The rules below keep the ones our plugins touch that way. If you add a
# reflection-heavy plugin later, add its keep rule here.

# ---- Flutter engine -------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ---- Google Play Core -----------------------------------------------------
# Flutter's embedding references Play Core (deferred components / split install)
# even when we don't use them. Without this R8 errors on missing classes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ---- Firebase (Auth, Messaging, Remote Config) ----------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ---- Google Sign-In / Google Maps (GMS) -----------------------------------
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ---- Gson (used internally by flutter_local_notifications) -----------------
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ---- flutter_local_notifications ------------------------------------------
-keep class com.dexterous.** { *; }

# ---- General Android hygiene ----------------------------------------------
-keepattributes SourceFile,LineNumberTable
-keep class * implements android.os.Parcelable { *; }
-keepclassmembers enum * { *; }
