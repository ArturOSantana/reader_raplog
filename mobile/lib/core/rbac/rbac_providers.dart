/// Providers Riverpod para o sistema RBAC da plataforma Lumen.
///
/// O [currentPrincipalProvider] é o ponto central de autorização do app.
/// Todos os guards, widgets condicionais e verificações de acesso leem daqui.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lumen_permission.dart';
import 'lumen_principal.dart';
import 'lumen_role.dart';
import 'lumen_rbac_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Serviço (singleton imutável)
// ─────────────────────────────────────────────────────────────────────────────

final rbacServiceProvider = Provider<LumenRbacService>(
  (_) => const LumenRbacService(),
  name: 'rbacServiceProvider',
);

// ─────────────────────────────────────────────────────────────────────────────
// Principal atual
// ─────────────────────────────────────────────────────────────────────────────

/// Carrega o principal do usuário autenticado a partir do Supabase.
///
/// O role é lido do campo `app_metadata.role` do token JWT do Supabase,
/// que é controlado exclusivamente pelo servidor (não pode ser forjado pelo cliente).
///
/// Fallback: [LumenRole.user] se o campo não existir.
final currentPrincipalProvider = FutureProvider<LumenPrincipal>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) return LumenPrincipal.anonymous;

  // Role vem do app_metadata (server-side, não pode ser alterado pelo cliente)
  final appMeta = user.appMetadata;
  final roleStr = appMeta['role'] as String?;
  final role = _parseRole(roleStr);

  // Clubes gerenciados vem do user_metadata (pode ser expandido futuramente)
  final userMeta = user.userMetadata ?? {};
  final managedClubs = (userMeta['managed_club_ids'] as List<dynamic>? ?? [])
      .map((e) => e.toString())
      .toSet();

  return LumenPrincipal(
    userId: user.id,
    role: role,
    managedClubIds: managedClubs,
  );
});

LumenRole _parseRole(String? raw) => switch (raw) {
  'super_admin' => LumenRole.superAdmin,
  'admin'       => LumenRole.admin,
  'support'     => LumenRole.support,
  'moderator'   => LumenRole.moderator,
  _             => LumenRole.user,
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de autorização (leitura síncrona a partir do cache do provider)
// ─────────────────────────────────────────────────────────────────────────────

/// Provider derivado: `true` se o usuário atual tiver a [permission].
///
/// Uso em widget:
/// ```dart
/// final canDelete = ref.watch(hasPermissionProvider(LumenPermission.reviewDelete));
/// ```
final hasPermissionProvider = Provider.family<bool, LumenPermission>(
  (ref, permission) {
    final async = ref.watch(currentPrincipalProvider);
    final principal = async.valueOrNull ?? LumenPrincipal.anonymous;
    return ref.watch(rbacServiceProvider).hasPermission(principal, permission);
  },
);

/// Provider derivado: `true` se o usuário atual pode acessar o admin panel.
final canAccessAdminProvider = Provider<bool>((ref) {
  final async = ref.watch(currentPrincipalProvider);
  final principal = async.valueOrNull ?? LumenPrincipal.anonymous;
  return ref.watch(rbacServiceProvider).canAccessAdmin(principal);
});
