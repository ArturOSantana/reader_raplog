import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'inspiration_quotes.dart';

/// Seleciona e entrega a frase certa para o momento certo.
///
/// Regras de seleção:
///  1. Filtra as frases pelo [InspirationContext] solicitado.
///  2. Evita repetir a última frase exibida naquele contexto
///     (armazenado localmente em SharedPreferences).
///  3. Se só houver uma frase no contexto, ela é sempre retornada.
class DailyInspirationService {
  static const _prefKeyPrefix = 'inspiration_last_idx_';

  /// Retorna uma frase aleatória para o [context] dado, evitando
  /// repetir a última exibida. Nunca retorna null — em último caso
  /// devolve a primeira frase do contexto.
  Future<InspirationQuote> pick(InspirationContext context) async {
    final pool =
        kInspirationQuotes.where((q) => q.context == context).toList();

    if (pool.isEmpty) {
      // Fallback genérico para contexto sem frases cadastradas
      return const InspirationQuote(
        quote: 'Cada página lida é um investimento em você.',
        context: InspirationContext.readingTime,
      );
    }

    if (pool.length == 1) return pool.first;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKeyPrefix${context.name}';
    final lastIdx = prefs.getInt(key) ?? -1;

    // Gera índice diferente do último
    int idx;
    do {
      idx = Random().nextInt(pool.length);
    } while (idx == lastIdx && pool.length > 1);

    await prefs.setInt(key, idx);
    return pool[idx];
  }

  /// Retorna uma frase síncrona (sem evitar repetição), útil para
  /// construção de widgets puros. Prefira [pick] quando possível.
  InspirationQuote pickSync(InspirationContext context) {
    final pool =
        kInspirationQuotes.where((q) => q.context == context).toList();
    if (pool.isEmpty) {
      return const InspirationQuote(
        quote: 'Cada página lida é um investimento em você.',
        context: InspirationContext.readingTime,
      );
    }
    return pool[Random().nextInt(pool.length)];
  }

  // ── Helpers semânticos ────────────────────────────────────────────────────

  /// Contexto correto com base no horário da sessão.
  static InspirationContext contextForSessionTime(DateTime at) {
    final h = at.hour;
    if (h < 10) return InspirationContext.morningReading;
    if (h >= 21) return InspirationContext.eveningReading;
    if (at.weekday == DateTime.sunday) return InspirationContext.sunday;
    return InspirationContext.readingTime;
  }

  /// Contexto para quando a streak foi mantida, com destaque para marcos.
  static InspirationContext contextForStreak({
    required int current,
    required int previous,
  }) {
    // Só considera recorde se a streak atual é maior que qualquer anterior
    if (current > previous) return InspirationContext.streakRecord;
    return InspirationContext.streakKept;
  }
}
