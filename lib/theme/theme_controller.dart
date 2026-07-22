// theme_controller.dart — Controlador de tema do ReadLog.
//
// Centraliza toda troca de tema: alterar, carregar e salvar preferência,
// notificando a interface sem reiniciar o aplicativo.
//
// Uso via Riverpod: ref.watch(themeModeProvider) / ref.read(themeModeProvider.notifier).set(mode)
// O provider está declarado em lib/shared/providers/providers.dart.

export 'theme_mode_storage.dart';
export 'readlog_theme.dart';
