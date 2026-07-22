# Configuração de Widgets Nativos — Readlog

Este documento descreve os passos necessários **no Xcode e no Android Studio** para completar a integração dos widgets nativos gerados pelo Flutter.

---

## Android

### 1. Nenhuma configuração adicional necessária

O `home_widget` usa `SharedPreferences` internamente.  
Os widgets são registrados automaticamente via `AndroidManifest.xml`.

### 2. Atualização do `build.gradle` (minSdk)

Certifique-se de que o `android/app/build.gradle` tem:

```gradle
minSdk = 21
```

---

## iOS

### 1. Criar o Widget Extension Target no Xcode

1. Abrir `ios/Runner.xcworkspace` no Xcode.
2. **File → New → Target → Widget Extension**.
3. Nome do produto: `ReadlogWidgets`.
4. **Language:** Swift.
5. **Include Configuration Intent:** desmarcar (usamos StaticConfiguration).
6. Clicar em **Finish** e aceitar "Activate ReadlogWidgets scheme".

### 2. Substituir o arquivo gerado

Substituir o conteúdo de `ReadlogWidgets/ReadlogWidgets.swift` pelo arquivo em:

```
ios/ReadlogWidgets/ReadlogWidgets.swift
```

### 3. Configurar o App Group

O `home_widget` usa App Groups para compartilhar dados entre o app Flutter e a Widget Extension.

#### No target Runner (app principal):

1. Signing & Capabilities → **+ Capability → App Groups**.
2. Adicionar: `group.com.readlog.readlog`.

#### No target ReadlogWidgets (widget extension):

1. Signing & Capabilities → **+ Capability → App Groups**.
2. Adicionar: `group.com.readlog.readlog`.

> O App Group deve ser idêntico em ambos os targets e corresponde a `WidgetKeys.iosAppGroup`.

### 4. Configurar o Bundle Identifier da Extension

No Xcode, selecionar o target `ReadlogWidgets`:

- **Bundle Identifier:** `com.readlog.readlog.ReadlogWidgets`

### 5. Verificar o Podfile

O Podfile já inclui o Runner. Adicionar ao final o target da extension:

```ruby
target 'ReadlogWidgets' do
  use_frameworks!
  use_modular_headers!
end
```

Em seguida:

```bash
cd ios && pod install
```

### 6. Build Settings da Extension

Em **ReadlogWidgets → Build Settings**:

- `SWIFT_VERSION`: 5.9+
- `IPHONEOS_DEPLOYMENT_TARGET`: 16.0 (WidgetKit exige ≥ 14.0; 16.0 para `.containerBackground`)

---

## Verificação

Ao finalizar a configuração:

1. Compilar o projeto: `flutter build ios` (ou build no Xcode).
2. No simulador, manter pressionada a tela inicial → **Personalizar** → pesquisar "Readlog".
3. Os 6 widgets devem aparecer: Ofensiva, Livro Atual, Meta Diária, Frase do Dia, Clube, Painel do Leitor.

---

## Deep Links (navegação dos widgets)

Os widgets Android disparam `intent.action` para abrir rotas específicas.  
Para que o `MainActivity` trate essas ações, adicionar ao `MainActivity.kt`:

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    when (intent.action) {
        "OPEN_SESSION"   -> /* navegar para /session */
        "OPEN_DASHBOARD" -> /* navegar para /dashboard */
        "OPEN_CLUBS"     -> /* navegar para /clubs */
        "OPEN_HOME"      -> /* navegar para /home */
    }
}
```

Para iOS, usar `widgetURL` ou `Link` nas views SwiftUI apontando para deep links do scheme `com.readlog.readlog://`.
