/// Escopo de aplicação de uma permissão.
///
/// Permite controle fino sobre o contexto em que uma permissão é válida.
///
/// Exemplos:
/// - `global` — vale para qualquer recurso
/// - `club`   — vale apenas dentro de um clube específico
/// - `own`    — vale apenas para recursos próprios do usuário
library;

enum LumenScope {
  /// Permissão vale globalmente (qualquer recurso, qualquer usuário).
  global,

  /// Permissão vale apenas dentro de um clube específico.
  /// O clubId é fornecido no momento da verificação.
  club,

  /// Permissão vale apenas para recursos que pertencem ao próprio usuário.
  own;
}
