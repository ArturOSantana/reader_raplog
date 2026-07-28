/// Papéis (roles) da plataforma Lumen.
///
/// Cada role carrega um conjunto pré-definido de permissões via [defaultPermissions].
/// Roles superiores herdam as permissões dos inferiores.
///
/// Hierarquia: user < moderator < support < admin < superAdmin
library;

import 'lumen_permission.dart';

enum LumenRole {
  user,
  moderator,
  support,
  admin,
  superAdmin;

  /// Permissões padrão atribuídas a este role.
  /// Roles superiores também carregam as permissões dos roles inferiores
  /// (ver [LumenRbacService.effectivePermissions]).
  Set<LumenPermission> get defaultPermissions => switch (this) {
    LumenRole.user => const {},

    LumenRole.moderator => {
      LumenPermission.reviewDelete,
      LumenPermission.reviewModerate,
      LumenPermission.reportsView,
      LumenPermission.reportsResolve,
    },

    LumenRole.support => {
      LumenPermission.userRead,
      LumenPermission.userBan,
      LumenPermission.userImpersonate,
      LumenPermission.billingView,
      LumenPermission.billingCoupon,
      LumenPermission.reportsView,
      LumenPermission.reportsResolve,
      LumenPermission.auditView,
    },

    LumenRole.admin => {
      LumenPermission.userRead,
      LumenPermission.userUpdate,
      LumenPermission.userDelete,
      LumenPermission.userBan,
      LumenPermission.userImpersonate,
      LumenPermission.reviewDelete,
      LumenPermission.reviewModerate,
      LumenPermission.bookEdit,
      LumenPermission.bookDelete,
      LumenPermission.clubManage,
      LumenPermission.clubDelete,
      LumenPermission.billingView,
      LumenPermission.billingRefund,
      LumenPermission.billingCoupon,
      LumenPermission.analyticsView,
      LumenPermission.analyticsExport,
      LumenPermission.featureFlagsEdit,
      LumenPermission.reportsView,
      LumenPermission.reportsResolve,
      LumenPermission.auditView,
      LumenPermission.systemSettings,
      LumenPermission.incidentManage,
      LumenPermission.fraudView,
      LumenPermission.fraudAction,
    },

    LumenRole.superAdmin => {
      ...LumenRole.admin.defaultPermissions,
      LumenPermission.rbacManage,
    },
  };
}
