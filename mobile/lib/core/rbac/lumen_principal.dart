/// Contexto de autenticação e autorização do usuário atual.
///
/// Criado pelo [currentPrincipalProvider] a partir do JWT do Supabase.
library;

import 'lumen_permission.dart';
import 'lumen_role.dart';

/// Representa o usuário autenticado com seu role e permissões.
class LumenPrincipal {
  final String userId;
  final LumenRole role;

  /// Permissões adicionais concedidas individualmente (além do role padrão).
  final Set<LumenPermission> extraPermissions;

  /// IDs de clubes onde este usuário tem papel de gestor/moderador.
  final Set<String> managedClubIds;

  const LumenPrincipal({
    required this.userId,
    required this.role,
    this.extraPermissions = const {},
    this.managedClubIds = const {},
  });

  static const LumenPrincipal anonymous = LumenPrincipal(
    userId: '',
    role: LumenRole.user,
  );

  bool get isAuthenticated => userId.isNotEmpty;
}
