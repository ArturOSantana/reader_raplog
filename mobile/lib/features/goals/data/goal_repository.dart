import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/goal.dart';

class GoalRepository {
  final SupabaseClient _client;

  GoalRepository(this._client);

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  Future<List<Goal>> fetchAll() async {
    final data = await _client
        .from('goals')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => Goal.fromMap(e)).toList();
  }

  Future<Goal> upsert({
    required GoalType type,
    required int targetValue,
  }) async {
    // Remove meta do mesmo tipo antes de inserir nova
    await _client
        .from('goals')
        .delete()
        .eq('user_id', _userId)
        .eq('type', type.dbValue);

    final data = await _client
        .from('goals')
        .insert({
          'user_id': _userId,
          'type': type.dbValue,
          'target_value': targetValue,
          'period': _periodForType(type),
        })
        .select()
        .single();
    return Goal.fromMap(data);
  }

  Future<void> delete(String id) async {
    await _client.from('goals').delete().eq('id', id).eq('user_id', _userId);
  }

  String _periodForType(GoalType type) {
    switch (type) {
      case GoalType.dailyPages:
      case GoalType.dailyMinutes:
        return 'daily';
      case GoalType.monthlyPages:
        return 'monthly';
      case GoalType.yearlyBooks:
        return 'yearly';
    }
  }
}
