// theme_mode_storage.dart — Persistência isolada do ThemeMode.
//
// Responsável exclusivamente por salvar e carregar a preferência de tema
// do usuário via SharedPreferences. Não contém lógica de negócio.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeStorage {
  ThemeModeStorage._();

  static const _key = 'theme_mode';

  /// Carrega o ThemeMode salvo. Retorna [ThemeMode.system] se não houver valor.
  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  /// Persiste o [mode] escolhido.
  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
