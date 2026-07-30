# Walkthrough - Correção de Crash no APK (Release)

As correções foram aplicadas para garantir que o aplicativo Lumen funcione corretamente em modo Release (APK), resolvendo falhas de rede, instabilidades de build e problemas de obfuscação de código.

## Mudanças Realizadas

### Estabilização do Ambiente de Build
- **Downgrade do Gradle & Kotlin**: Alteramos as versões experimentais para versões estáveis e amplamente suportadas.
    - Android Gradle Plugin: `9.0.1` → `8.5.1`
    - Kotlin: `2.3.20` → `1.9.24`
- Isso garante que plugins como `home_widget` funcionem conforme o esperado.

### Configuração de Rede e Permissões
- Adicionadas as permissões essenciais ao `AndroidManifest.xml` principal:
    - `android.permission.INTERNET`: Necessária para Supabase, Google Sign-In e atualizações remotas.
    - `android.permission.ACCESS_NETWORK_STATE`: Permite que o app verifique se há conexão antes de tentar operações de rede.

### Proteção contra Obfuscação (R8/ProGuard)
- **Novo arquivo de regras**: Criado o [proguard-rules.pro](file:///Users/artur.santana/pessoal/readlog/mobile/android/app/proguard-rules.pro) para instruir o Android a **não** remover ou renomear classes críticas do Flutter e dos seus Widgets nativos.
- **Ativação do Minify**: Configuramos o build de release para usar essas regras, o que também ajuda a reduzir levemente o tamanho do APK final de forma segura.

### Segurança no Código Nativo (Kotlin)
- Refatoramos todos os Widgets (`StreakWidget`, `CurrentBookWidget`, etc.) para usar referências de classe seguras (`MainActivity::class.java`). Isso evita erros de "Classe não encontrada" caso o processo de build altere o nome dos pacotes em tempo de compilação.

## Próximos Passos

1.  **Limpar o Build**: Execute o comando abaixo no terminal para garantir que não haja sobras das versões anteriores:
    ```bash
    flutter clean
    flutter pub get
    ```
2.  **Gerar novo APK**:
    ```bash
    flutter build apk --release
    ```
3.  **Testar no Celular**: Instale o novo APK gerado em `build/app/outputs/flutter-apk/app-release.apk`.

> [!TIP]
> Se o app ainda apresentar problemas com o Google Sign-In, verifique se a **SHA-1 do certificado de release** foi adicionada ao Console do Firebase/Google Cloud, pois ela é diferente da SHA-1 de debug usada durante o desenvolvimento.
