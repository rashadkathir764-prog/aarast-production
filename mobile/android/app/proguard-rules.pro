# Flutter engine and plugin entry points are reached via JNI/reflection,
# so R8 must not strip them.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage uses Android Keystore classes reflectively.
-keep class androidx.security.crypto.** { *; }

# sqflite_sqlcipher loads SQLCipher classes through JNI/reflection. The
# package documents this keep rule as mandatory for shrunk Release builds.
-keep class net.sqlcipher.** { *; }

# The Flutter engine references Play Core deferred-component classes even
# when the app ships no deferred components; the classes are absent by
# design, so R8 must not fail on them.
-dontwarn com.google.android.play.core.**
