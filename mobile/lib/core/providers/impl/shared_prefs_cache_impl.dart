/// Implementação persistente do [CacheProvider] usando SharedPreferences.
///
/// Os valores são serializados como JSON e persistidos entre sessões do app.
/// Ideal para cache de respostas de API (Google Books, perfis, clubes).
///
/// Limitações:
/// - Suporta apenas tipos primitivos e coleções serializáveis em JSON.
/// - Não adequada para objetos complexos com tipos customizados.
/// - Para cache de alta performance em servidor, usar UpstashCacheImpl (Fase 2).
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../cache_provider.dart';

class SharedPrefsCacheImpl implements CacheProvider {
  SharedPrefsCacheImpl(this._prefs);

  final SharedPreferences _prefs;

  // Prefixo interno para não colidir com outras chaves de SharedPreferences.
  static const _ns = 'lumen_cache::';
  // Sufixo onde o TTL expirado é armazenado (timestamp Unix em ms).
  static const _ttlSuffix = '::ttl';

  String _k(String key) => '$_ns$key';
  String _ttlK(String key) => '$_ns$key$_ttlSuffix';

  @override
  Future<T?> get<T>(String key) async {
    // Verifica TTL antes de ler o valor.
    final ttlRaw = _prefs.getInt(_ttlK(key));
    if (ttlRaw != null) {
      if (DateTime.now().millisecondsSinceEpoch > ttlRaw) {
        await delete(key);
        return null;
      }
    }
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as T?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    await _prefs.setString(_k(key), jsonEncode(value));
    if (ttl != null) {
      final expiresAt =
          DateTime.now().add(ttl).millisecondsSinceEpoch;
      await _prefs.setInt(_ttlK(key), expiresAt);
    } else {
      await _prefs.remove(_ttlK(key));
    }
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(_k(key));
    await _prefs.remove(_ttlK(key));
  }

  @override
  Future<void> invalidatePrefix(String prefix) async {
    final fullPrefix = '$_ns$prefix';
    final keys = _prefs.getKeys().where((k) => k.startsWith(fullPrefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  @override
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_ns));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  @override
  Future<bool> has(String key) async {
    final ttlRaw = _prefs.getInt(_ttlK(key));
    if (ttlRaw != null &&
        DateTime.now().millisecondsSinceEpoch > ttlRaw) {
      await delete(key);
      return false;
    }
    return _prefs.containsKey(_k(key));
  }
}
