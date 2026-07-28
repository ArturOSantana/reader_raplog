/// Implementação em memória do [CacheProvider].
///
/// Ideal para desenvolvimento, testes e caching in-process sem dependências.
/// Os dados são perdidos ao reiniciar o app.
library;

import 'dart:async';
import '../cache_provider.dart';

class _CacheEntry {
  final Object? value;
  final DateTime? expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class MemoryCacheImpl implements CacheProvider {
  final _store = <String, _CacheEntry>{};

  @override
  Future<T?> get<T>(String key) async {
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    final expiresAt = ttl != null ? DateTime.now().add(ttl) : null;
    _store[key] = _CacheEntry(value, expiresAt);
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> invalidatePrefix(String prefix) async {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<bool> has(String key) async {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return false;
    return true;
  }
}
