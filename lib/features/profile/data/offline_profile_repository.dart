import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/user_profile.dart';
import '../../../core/local/sync_queue.dart';
import 'local_profile_repository.dart';

/// Repositório offline-first para o perfil do usuário.
///
/// Quando online: lê/escreve no Supabase e mantém o cache local atualizado.
/// Quando offline: lê/escreve apenas no SQLite e enfileira para sincronização.
class OfflineProfileRepository {
  final SupabaseClient _client;
  final bool Function() _isOnline;
  final LocalProfileRepository _local = LocalProfileRepository();

  OfflineProfileRepository(this._client, this._isOnline);

  String get _userId => _client.auth.currentUser!.id;

  Future<UserProfile?> fetch() async {
    if (_isOnline()) {
      try {
        final data = await _client
            .from('profiles')
            .select()
            .eq('id', _userId)
            .maybeSingle();
        if (data != null) {
          final profile = UserProfile.fromMap(data);
          await _local.upsert({...profile.toMap(), 'id': _userId, 'updated_at': profile.updatedAt.toIso8601String()});
          return profile;
        }
      } catch (_) {
        // Sem rede — usa cache
      }
    }
    return _local.fetch(_userId);
  }

  Future<UserProfile> upsert(Map<String, dynamic> fields) async {
    final now = DateTime.now().toIso8601String();
    final localPayload = {...fields, 'id': _userId, 'updated_at': now};

    // Persiste localmente de imediato (optimistic)
    await _local.upsert(localPayload);

    if (_isOnline()) {
      try {
        final data = await _client
            .from('profiles')
            .upsert({...fields, 'id': _userId})
            .select()
            .single();
        final profile = UserProfile.fromMap(data);
        // Atualiza cache com os dados confirmados pelo servidor
        await _local.upsert({...profile.toMap(), 'id': _userId, 'updated_at': profile.updatedAt.toIso8601String()});
        return profile;
      } catch (_) {
        // Falha na rede — encaminha para a fila de sincronização
        await SyncQueue.instance.enqueue(
          entity: 'profiles',
          operation: 'upsert',
          payload: {...fields, 'id': _userId},
        );
      }
    } else {
      await SyncQueue.instance.enqueue(
        entity: 'profiles',
        operation: 'upsert',
        payload: {...fields, 'id': _userId},
      );
    }

    // Retorna a versão local como confirmação imediata
    return UserProfile(
      id: _userId,
      name: fields['name'] as String?,
      bio: fields['bio'] as String?,
      avatarUrl: fields['avatar_url'] as String?,
      yearlyGoal: fields['yearly_goal'] as int?,
      favoriteGenre: fields['favorite_genre'] as String?,
      updatedAt: DateTime.now(),
    );
  }
}
