import 'package:shared_preferences/shared_preferences.dart';

const _kLastRouteKey = 'last_route';

/// Rotas que devem ser restauradas ao reabrir o app.
///
/// Apenas rotas "simples" (sem dados em memória via `extra`) são permitidas.
/// Rotas que dependem de `extra` (objetos em memória que não sobrevivem ao
/// cold start) causam crash ao tentar restaurar — ex: EditBookScreen, que
/// espera um objeto `Book` via `state.extra`.
const _kAllowedRoutes = {
  '/home',
  '/library',
  '/dashboard',
  '/achievements',
  '/goals',
  '/wishlist',
  '/profile',
  '/friends',
  '/calendar',
  '/social',
  '/clubs',
  '/notifications',
  '/notifications/settings',
};

/// Retorna `true` se a rota pode ser persistida com segurança.
bool _shouldPersist(String? location) {
  if (location == null) return false;
  if (location.startsWith('/auth')) return false;
  // Verifica correspondência exata ou prefixo permitido
  for (final allowed in _kAllowedRoutes) {
    if (location == allowed || location.startsWith('$allowed/')) {
      // Rotas de detalhe dentro de /library ou /friends ou /clubs são ok
      // se não houver segmentos que dependam de `extra`
      if (location.startsWith('/library/book/') &&
          location.endsWith('/edit')) {
        return false; // EditBookScreen depende de extra
      }
      if (location == '/notifications/schedule') {
        return false; // ReadingScheduleScreen depende de extra
      }
      return true;
    }
  }
  return false;
}

Future<String?> loadLastRoute() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kLastRouteKey);
  if (!_shouldPersist(saved)) {
    // Limpa automaticamente rotas inválidas/não-restauráveis salvas por
    // versões anteriores do app, evitando crash no cold start.
    if (saved != null) {
      await prefs.remove(_kLastRouteKey);
    }
    return null;
  }
  return saved;
}

Future<void> saveLastRoute(String location) async {
  if (!_shouldPersist(location)) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastRouteKey, location);
}
