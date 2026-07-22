import 'package:shared_preferences/shared_preferences.dart';

const _kLastRouteKey = 'last_route';

/// Rotas que não devem ser persistidas (ex: tela de login).
bool _shouldPersist(String? location) {
  if (location == null) return false;
  if (location.startsWith('/auth')) return false;
  return true;
}

Future<String?> loadLastRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kLastRouteKey);
  if (!_shouldPersist(saved)) return null;
  return saved;
}

Future<void> saveLastRoute(String location) async {
  if (!_shouldPersist(location)) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastRouteKey, location);
}
