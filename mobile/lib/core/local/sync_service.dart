import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/sync_queue.dart';

/// Drena a fila de operações pendentes enviando-as ao Supabase.
/// Deve ser chamado quando a conectividade for restaurada.
class SyncService {
  final SupabaseClient _client;

  SyncService(this._client);

  Future<void> sync() async {
    final pending = await SyncQueue.instance.fetchPending();
    for (final op in pending) {
      try {
        await _dispatch(op);
        await SyncQueue.instance.remove(op.id);
      } catch (_) {
        // Interrompe ao primeiro erro para preservar a ordem
        break;
      }
    }
  }

  Future<void> _dispatch(PendingOperation op) async {
    final table = _entityToTable(op.entity);
    switch (op.operation) {
      case 'insert':
        await _client.from(table).upsert(op.payload);
      case 'update':
        final id = op.payload['id'] as String;
        final fields = Map<String, dynamic>.from(op.payload)..remove('id');
        await _client.from(table).update(fields).eq('id', id);
      case 'delete':
        final id = op.payload['id'] as String;
        await _client.from(table).delete().eq('id', id);
    }
  }

  String _entityToTable(String entity) {
    switch (entity) {
      case 'book':
        return 'books';
      case 'session':
        return 'reading_sessions';
      case 'note':
        return 'notes';
      case 'profile':
        return 'profiles';
      default:
        return entity;
    }
  }
}
