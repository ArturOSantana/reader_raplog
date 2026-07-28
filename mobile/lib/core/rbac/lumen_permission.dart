/// Permissões granulares da plataforma Lumen.
///
/// Regra fundamental: nunca verificar `role == admin` no código.
/// Sempre verificar a permissão específica necessária.
///
/// Exemplo:
/// ```dart
/// // ❌ Errado
/// if (role == LumenRole.admin) { ... }
///
/// // ✓ Correto
/// if (rbac.hasPermission(userId, LumenPermission.reviewDelete)) { ... }
/// ```
library;

/// Permissões atômicas da plataforma.
///
/// Nomenclatura: `recurso.ação`
enum LumenPermission {
  // ── Usuários ──────────────────────────────────────────────────────────────
  userRead,
  userUpdate,
  userDelete,
  userImpersonate,    // Entrar como outro usuário (Support)
  userBan,

  // ── Reviews ───────────────────────────────────────────────────────────────
  reviewDelete,
  reviewModerate,

  // ── Livros ────────────────────────────────────────────────────────────────
  bookEdit,
  bookDelete,

  // ── Clubes ────────────────────────────────────────────────────────────────
  clubManage,
  clubDelete,

  // ── Billing ───────────────────────────────────────────────────────────────
  billingView,
  billingRefund,
  billingCoupon,

  // ── Analytics ─────────────────────────────────────────────────────────────
  analyticsView,
  analyticsExport,

  // ── Feature Flags ─────────────────────────────────────────────────────────
  featureFlagsEdit,

  // ── Reports / Denúncias ───────────────────────────────────────────────────
  reportsView,
  reportsResolve,

  // ── Audit ─────────────────────────────────────────────────────────────────
  auditView,

  // ── Sistema ───────────────────────────────────────────────────────────────
  systemSettings,
  incidentManage,

  // ── Fraud ─────────────────────────────────────────────────────────────────
  fraudView,
  fraudAction,

  // ── RBAC ─────────────────────────────────────────────────────────────────
  rbacManage,
}
