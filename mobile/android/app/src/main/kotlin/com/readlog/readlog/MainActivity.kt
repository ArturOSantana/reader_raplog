package com.readlog.readlog

import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity

// @Keep garante que o R8 nunca remove esta classe, mesmo sem regras ProGuard.
// É referenciada apenas pelo AndroidManifest (via string), não por código Kotlin,
// portanto sem @Keep o R8 a remove como "não usada".
@Keep
class MainActivity : FlutterActivity()
