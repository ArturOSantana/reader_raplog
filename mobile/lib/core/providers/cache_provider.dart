/// Interface de cache genérico da plataforma.
///
/// Implementações disponíveis:
/// - [MemoryCacheImpl]         — in-process, sem persistência
/// - [SharedPrefsCacheImpl]    — persistência leve via SharedPreferences
///
/// Futuro: Redis (Upstash), Memcached.
library;

import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class CacheProvider {
  /// Retorna o valor armazenado ou `null` se ausente/expirado.
  Future<T?> get<T>(String key);

  /// Persiste [value] por até [ttl]. Sem [ttl] = sem expiração.
  Future<void> set<T>(String key, T value, {Duration? ttl});

  /// Remove a entrada.
  Future<void> delete(String key);

  /// Remove todas as entradas cujo prefixo corresponda a [prefix].
  Future<void> invalidatePrefix(String prefix);

  /// Remove todo o cache.
  Future<void> clear();

  /// Retorna `true` se a chave existir e não estiver expirada.
  Future<bool> has(String key);
}

// ─────────────────────────────────────────────────────────────────────────────
// Prefixos de cache padronizados para a plataforma
// ─────────────────────────────────────────────────────────────────────────────

/// Prefixos canônicos — usar sempre estes para garantir invalidação consistente.
abstract final class CacheKeys {
  CacheKeys._();

  static const String book          = 'book:';
  static const String author        = 'author:';
  static const String club          = 'club:';
  static const String googleBooks   = 'gbooks:';
  static const String homepage      = 'home:';
  static const String rankings      = 'rankings:';
  static const String seo           = 'seo:';
  static const String analytics     = 'analytics:';
  static const String profile       = 'profile:';

  static String bookById(String id)        => '$book$id';
  static String gBooksByQuery(String q)    => '${googleBooks}q:$q';
  static String gBookById(String id)       => '${googleBooks}id:$id';
  static String clubById(String id)        => '$club$id';
  static String profileById(String userId) => '$profile$userId';
}
