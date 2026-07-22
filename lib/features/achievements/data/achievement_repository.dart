import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/achievement.dart';

class AchievementRepository {
  final SupabaseClient _client;

  AchievementRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Achievement>> fetchAll() async {
    final data = await _client
        .from('achievements')
        .select('*, user_achievements!left(unlocked_at, user_id)')
        .eq('user_achievements.user_id', _userId)
        .order('xp_reward', ascending: true);

    return (data as List).map((e) {
      final userUnlocks = e['user_achievements'] as List?;
      final unlockedAt = (userUnlocks != null && userUnlocks.isNotEmpty)
          ? DateTime.parse(userUnlocks.first['unlocked_at'] as String)
          : null;
      return Achievement.fromMap({...e, 'unlocked_at': unlockedAt?.toIso8601String()});
    }).toList();
  }

  Future<void> unlock(String achievementId) async {
    await _client.from('user_achievements').upsert({
      'user_id': _userId,
      'achievement_id': achievementId,
    });
  }
}
