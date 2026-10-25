# shared_preferences_android calls its Kotlin code from Dart over JNI
# (jnigen). R8 doesn't see those calls and strips the methods, so in release
# the app hung on the logo with NoSuchMethodError when reading the data.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# JNI signatures include Kotlin types (e.g. getAll(..., Continuation)): if R8
# renames them the signature stops matching and the NoSuchMethodError returns.
# The bridge also looks up kotlin.Result, kotlin.Unit, etc. by name, so the
# whole Kotlin runtime is kept.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }

# Runtime of the jni package those bridges use.
-keep class com.github.dart_lang.jni.** { *; }

# Health Connect: the plugin creates records by reflection / class name.
-keep class androidx.health.** { *; }
-keep class cachet.plugins.health.** { *; }
