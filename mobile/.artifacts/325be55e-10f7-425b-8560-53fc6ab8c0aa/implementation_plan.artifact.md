# Plano de Implementação - Correção de Crash no APK (Release)

Este plano visa corrigir o erro onde o aplicativo fecha imediatamente após ser instalado via APK (modo Release) no celular. Identificamos que a falta de permissão de internet e o uso de versões experimentais do Gradle/Kotlin são os prováveis causadores, além da necessidade de regras de obfuscação para os widgets nativos.

## User Review Required

> [!IMPORTANT]
> **Downgrade de Versões:** Vou reverter o Android Gradle Plugin de `9.0.1` para `8.5.1` e o Kotlin de `2.3.20` para `1.9.24`. Estas são versões estáveis recomendadas para a maioria dos projetos Flutter atuais. O uso de versões experimentais pode causar falhas silenciosas em plugins nativos.

> [!WARNING]
> **Permissão de Internet:** Adicionarei explicitamente a permissão de internet no manifesto principal. Sem isso, o Supabase e o Google Sign-In falham ao tentar abrir conexões de rede em modo Release.

## Proposed Changes

### Android Build Configuration

#### [MODIFY] [settings.gradle.kts](file:///Users/artur.santana/pessoal/readlog/mobile/android/settings.gradle.kts)
- Alterar a versão do plugin `com.android.application` para `8.5.1`.
- Alterar a versão do plugin `org.jetbrains.kotlin.android` para `1.9.24`.

#### [MODIFY] [build.gradle.kts](file:///Users/artur.santana/pessoal/readlog/mobile/android/app/build.gradle.kts)
- Configurar o bloco `buildTypes.release` para usar o arquivo de regras do ProGuard.
- Garantir a compatibilidade do Java 17.

#### [NEW] [proguard-rules.pro](file:///Users/artur.santana/pessoal/readlog/mobile/android/app/proguard-rules.pro)
- Adicionar regras para manter as classes de Widgets nativos (`com.readlog.readlog.widgets.*`) e classes do Flutter/HomeWidget.

### Android Manifest & Permissions

#### [MODIFY] [AndroidManifest.xml](file:///Users/artur.santana/pessoal/readlog/mobile/android/app/src/main/AndroidManifest.xml)
- Adicionar `<uses-permission android:name="android.permission.INTERNET"/>`.
- Adicionar `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>`.

### Native Widgets Safety

#### [MODIFY] Widgets Kotlin Files (e.g., [StreakWidget.kt](file:///Users/artur.santana/pessoal/readlog/mobile/android/app/src/main/kotlin/com/readlog/readlog/widgets/StreakWidget.kt))
- Substituir o uso de `Class.forName("com.readlog.readlog.MainActivity")` por `MainActivity::class.java` para evitar erros caso a classe MainActivity seja renomeada pelo R8 (mesmo com ProGuard, referências diretas são melhores).

## Verification Plan

### Automated Tests
- Executar `./gradlew clean` na pasta `android` para limpar builds antigos.
- Tentar realizar um build de release localmente: `flutter build apk --release`.

### Manual Verification
- Instalar o APK gerado no emulador.
- Monitorar o `adb logcat` filtrando pela tag do app para garantir que nenhuma `ClassNotFoundException` ocorra durante a inicialização.
