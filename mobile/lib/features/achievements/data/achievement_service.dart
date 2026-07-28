import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/achievement.dart';

/// Serviço responsável por verificar e desbloquear conquistas automaticamente.
///
/// Chamado após finalizar uma sessão ou marcar um livro como lido.
class AchievementService {
  final SupabaseClient _client;

  AchievementService(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  /// Retorna lista de conquistas recém desbloqueadas (para exibir notificação).
  Future<List<Achievement>> checkAndUnlock({
    required int totalPagesRead,
    required int totalMinutesRead,
    required int totalBooksRead,
    required int currentStreak,
    required int pagesInSession,
    required bool isNightSession,
    required int totalNotesAndHighlights,
    required int totalSessions,
  }) async {
    // Busca conquistas já desbloqueadas
    final unlockedData = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', _userId);
    final unlockedIds =
        Set<String>.from((unlockedData as List).map((e) => e['achievement_id']));

    // Busca todas as conquistas
    final allData = await _client
        .from('achievements')
        .select()
        .order('xp_reward', ascending: true);
    final achievements =
        (allData as List).map((e) => Achievement.fromMap(e)).toList();

    final toUnlock = <Achievement>[];

    for (final a in achievements) {
      if (unlockedIds.contains(a.id)) continue;

      final shouldUnlock = _shouldUnlock(
        key: a.key,
        totalPagesRead: totalPagesRead,
        totalMinutesRead: totalMinutesRead,
        totalBooksRead: totalBooksRead,
        currentStreak: currentStreak,
        pagesInSession: pagesInSession,
        isNightSession: isNightSession,
        totalNotesAndHighlights: totalNotesAndHighlights,
        totalSessions: totalSessions,
      );

      if (shouldUnlock) {
        toUnlock.add(a);
      }
    }

    if (toUnlock.isNotEmpty) {
      await _client.from('user_achievements').insert(
            toUnlock
                .map((a) => {'user_id': _userId, 'achievement_id': a.id})
                .toList(),
          );
    }

    return toUnlock;
  }

  bool _shouldUnlock({
    required String key,
    required int totalPagesRead,
    required int totalMinutesRead,
    required int totalBooksRead,
    required int currentStreak,
    required int pagesInSession,
    required bool isNightSession,
    required int totalNotesAndHighlights,
    required int totalSessions,
  }) {
    switch (key) {
      case 'first_session':
        return totalSessions >= 1;
      case 'first_book':
        return totalBooksRead >= 1;
      case 'pages_100':
        return totalPagesRead >= 100;
      case 'pages_500':
        return totalPagesRead >= 500;
      case 'pages_1000':
        return totalPagesRead >= 1000;
      case 'streak_3':
        return currentStreak >= 3;
      case 'streak_7':
        return currentStreak >= 7;
      case 'streak_30':
        return currentStreak >= 30;
      case 'books_5':
        return totalBooksRead >= 5;
      case 'books_10':
        return totalBooksRead >= 10;
      case 'hours_10':
        return totalMinutesRead >= 600;
      case 'hours_100':
        return totalMinutesRead >= 6000;
      case 'night_owl':
        return isNightSession;
      case 'speed_reader':
        return pagesInSession >= 60;
      case 'annotator':
        return totalNotesAndHighlights >= 10;
      default:
        return false;
    }
  }

  /// Coleta os dados necessários para verificar conquistas.
  Future<Map<String, dynamic>> collectStats({
    required int pagesInSession,
    required int durationMinutes,
    required DateTime sessionStartedAt,
  }) async {
    // Total de páginas, minutos e contagem de sessões concluídas
    final sessionsData = await _client
        .from('reading_sessions')
        .select('pages_read, duration_minutes')
        .eq('user_id', _userId)
        .not('ended_at', 'is', null);

    int totalPages = 0;
    int totalMinutes = 0;
    for (final row in (sessionsData as List)) {
      totalPages += (row['pages_read'] as num?)?.toInt() ?? 0;
      totalMinutes += (row['duration_minutes'] as num?)?.toInt() ?? 0;
    }
    final totalSessions = (sessionsData as List).length;

    // Total de livros lidos
    final booksData = await _client
        .from('books')
        .select('id')
        .eq('user_id', _userId)
        .eq('status', 'read');
    final totalBooks = (booksData as List).length;

    // Streak atual
    final streakData =
        await _client.rpc('calculate_streak', params: {'p_user_id': _userId});
    final streak = (streakData as int?) ?? 0;

    // Total de notas + highlights
    final notesData = await _client
        .from('notes')
        .select('id')
        .eq('user_id', _userId);
    final highlightsData = await _client
        .from('highlights')
        .select('id')
        .eq('user_id', _userId);
    final totalAnnotations =
        (notesData as List).length + (highlightsData as List).length;

    // Sessão noturna: entre 00:00 e 04:00
    final hour = sessionStartedAt.hour;
    final isNight = hour >= 0 && hour < 4;

    return {
      'total_pages': totalPages,
      'total_minutes': totalMinutes,
      'total_books': totalBooks,
      'streak': streak,
      'pages_in_session': pagesInSession,
      'is_night': isNight,
      'total_annotations': totalAnnotations,
      'total_sessions': totalSessions,
    };
  }
}
