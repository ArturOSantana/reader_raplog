# Flutter Keep
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# HomeWidget Plugin
-keep class es.antonborri.home_widget.** { *; }

# Nossos Widgets Nativos
-keep class com.readlog.readlog.widgets.** { *; }

# MainActivity (não deve ser renomeada pois é referenciada por nome no manifesto e código)
-keep class com.readlog.readlog.MainActivity { *; }

# Google Services / Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Supabase / HTTP
-keep class com.squareup.okhttp3.** { *; }
-keep class retrofit2.** { *; }

# Ignorar avisos de bibliotecas que não afetam o runtime do Flutter
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.gms.**
