# Flutter engine and plugin entry points are reached via JNI/reflection,
# so R8 must not strip them.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# sqflite_sqlcipher 3.4 loads net.zetetic:sqlcipher-android through
# JNI/reflection. RA-MO-104: the rule kept net.sqlcipher, a package the
# library no longer has, so it kept nothing; it now names the classes in use
# (the library's own rules keep only its native members).
-keep class net.zetetic.database.sqlcipher.** { *; }

# RA-MO-104: flutter_secure_storage 10 encrypts with Tink, which ships its
# own keep rules; the rule for androidx.security.crypto, no longer used, is
# gone.

# The Flutter engine references Play Core deferred-component classes even
# when the app ships no deferred components; the classes are absent by
# design, so R8 must not fail on them.
-dontwarn com.google.android.play.core.**
