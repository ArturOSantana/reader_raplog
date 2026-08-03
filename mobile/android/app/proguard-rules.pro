# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ─── App classes ──────────────────────────────────────────────────────────────
# MainActivity: mantida pelo nome (referenciada no AndroidManifest) e pela
# hierarquia de herança do Flutter embedding (FlutterActivity → Activity).
-keep public class com.readlog.readlog.MainActivity
-keepclassmembers public class com.readlog.readlog.MainActivity { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity
-keep class * extends io.flutter.embedding.android.FlutterFragmentActivity

# Widgets nativos (referenciados por nome no AndroidManifest)
-keep class com.readlog.readlog.widgets.** { *; }

# ─── HomeWidget plugin ────────────────────────────────────────────────────────
-keep class es.antonborri.home_widget.** { *; }

# ─── SQLite / sqflite ─────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
# Evita remoção de métodos nativos JNI usados pelo SQLite
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─── Supabase / PostgREST / Ktor ──────────────────────────────────────────────
# Supabase usa Kotlin serialization via reflexão — manter todos os modelos
-keep @kotlinx.serialization.Serializable class ** { *; }
-keepclassmembers class ** {
    @kotlinx.serialization.SerialName <fields>;
}
# OkHttp (usado internamente pelo Supabase/Ktor)
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**
-keep interface com.squareup.okhttp3.** { *; }

# ─── Retrofit (transitivo de alguns plugins) ──────────────────────────────────
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# ─── Google Services / Firebase ───────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Google Sign-In ───────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }

# ─── connectivity_plus ────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─── flutter_local_notifications ──────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ─── share_plus ───────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ─── image_picker ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ─── cached_network_image / Flutter Image Cache ───────────────────────────────
# Mantém callbacks de bitmap para evitar problemas de cache em release
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ─── JSON / Serialização genérica ─────────────────────────────────────────────
# Para qualquer lib que usa reflexão em campos anotados
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
