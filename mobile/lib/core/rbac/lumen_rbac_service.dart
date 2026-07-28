/// Serviço central de autorização da plataforma Lumen.
///
/// Toda verificação de acesso deve passar por este serviço.
/// Nunca comparar roles diretamente no código de apresentação.
///
/// Uso:
/// ```dart
/// // Verificar permissão global
/// final canDelete = rbac.hasPermission(principal, LumenPermission.reviewDelete);
///
/// // Verificar permissão no escopo de clube
/// final canManage = rbac.hasPermissionInScope(
///   principal,
///   LumenPermission.clubManage,
///   scope: LumenScope.club,
///   clubId: '...',
/// );
/// ```
library;

import 'lumen_permission.dart';
import 'lumen_principal.dart';
import 'lumen_role.dart';
import 'lumen_scope.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Serviço
// ─────────────────────────────────────────────────────────────────────────────

class LumenRbacService {
  const LumenRbacService();

  /// Retorna o conjunto efetivo de permissões do principal.
  /// Inclui as permissões do role + permissões extras concedidas individualmente.
  Set<LumenPermission> effectivePermissions(LumenPrincipal principal) {
    return {
      ...principal.role.defaultPermissions,
      ...principal.extraPermissions,
    };
  }

  /// Verifica se o principal tem a permissão no escopo global.
  bool hasPermission(LumenPrincipal principal, LumenPermission permission) {
    return effectivePermissions(principal).contains(permission);
  }

  /// Verifica se o principal tem a permissão em um escopo específico.
  ///
  /// - [LumenScope.global] — equivale a [hasPermission]
  /// - [LumenScope.club]   — exige que [clubId] seja um clube gerenciado
  /// - [LumenScope.own]    — exige que [ownerId] seja o próprio usuário
  bool hasPermissionInScope(
    LumenPrincipal principal,
    LumenPermission permission, {
    required LumenScope scope,
    String? clubId,
    String? ownerId,
  }) {
    // Super admins e admins com permissão global passam sempre
    if (hasPermission(principal, permission)) {
      if (scope == LumenScope.global) return true;

      // Verifica o escopo adicional
      if (scope == LumenScope.club && clubId != null) {
        return principal.managedClubIds.contains(clubId);
      }
      if (scope == LumenScope.own && ownerId != null) {
        return ownerId == principal.userId;
      }
    }
    return false;
  }

  /// Retorna `true` se o principal pode acessar o painel admin.
  bool canAccessAdmin(LumenPrincipal principal) {
    return principal.role != LumenRole.user;
  }

  /// Verifica a role mínima necessária.
  bool hasMinimumRole(LumenPrincipal principal, LumenRole minimumRole) {
    return principal.role.index >= minimumRole.index;
  }
}
