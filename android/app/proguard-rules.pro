# shared_preferences_android llama a su código Kotlin desde Dart por JNI
# (jnigen). R8 no ve esas llamadas y elimina los métodos, así que en release
# la app se quedaba colgada en el logo con NoSuchMethodError al leer los datos.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Las firmas JNI incluyen tipos de Kotlin (p. ej. getAll(..., Continuation)):
# si R8 los renombra, la firma deja de coincidir y vuelve el NoSuchMethodError.
# El puente también busca por nombre kotlin.Result, kotlin.Unit, etc., así que
# se conserva todo el runtime de Kotlin.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }

# Runtime del paquete jni que usan esos puentes.
-keep class com.github.dart_lang.jni.** { *; }

# Health Connect: el plugin crea los registros por reflexión/nombre de clase.
-keep class androidx.health.** { *; }
-keep class cachet.plugins.health.** { *; }
