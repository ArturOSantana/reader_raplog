import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../theme/lumen_theme.dart';

/// Shell exclusiva do painel admin — completamente separada do [MainShell] do app.
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: ReadLogColors.surface,
        body: Row(
          children: [
            _AdminNavRail(currentLocation: location),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ReadLogColors.surface,
      appBar: _AdminAppBar(location: location),
      drawer: _AdminDrawer(currentLocation: location),
      body: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String location;
  const _AdminAppBar({required this.location});

  String _title() {
    if (location.startsWith('/admin/users')) return 'Usuários';
    if (location.startsWith('/admin/clubs')) return 'Clubes';
    if (location.startsWith('/admin/reports')) return 'Denúncias';
    if (location.startsWith('/admin/subscriptions')) return 'Assinaturas';
    if (location.startsWith('/admin/metrics')) return 'Métricas';
    return 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ReadLogColors.ink,
      foregroundColor: ReadLogColors.inkInverse,
      elevation: 0,
      title: Text(
        'ADMIN · ${_title().toUpperCase()}',
        style: ReadLogType.mono(
          size: 12,
          weight: FontWeight.w600,
          color: ReadLogColors.inkInverse,
        ).copyWith(letterSpacing: 2),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Rail (desktop / tablet)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminNavRail extends StatelessWidget {
  final String currentLocation;
  const _AdminNavRail({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: ReadLogColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUMEN',
                  style: ReadLogType.display(
                    size: 20,
                    color: ReadLogColors.inkInverse,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ADMIN PANEL',
                  style: ReadLogType.mono(
                    size: 9,
                    color: ReadLogColors.progress,
                  ).copyWith(letterSpacing: 3),
                ),
              ],
            ),
          ),
          Divider(color: ReadLogColors.hairlineDark, height: 1),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildItems(context),
            ),
          ),
          // Voltar ao app
          Divider(color: ReadLogColors.hairlineDark, height: 1),
          _NavItem(
            icon: Icons.arrow_back_outlined,
            label: 'Voltar ao App',
            active: false,
            onTap: () => context.go('/home'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) => [
        _NavItem(
          icon: Icons.dashboard_outlined,
          label: 'Overview',
          active: currentLocation == '/admin',
          onTap: () => context.go('/admin'),
        ),
        _NavItem(
          icon: Icons.people_outline,
          label: 'Usuários',
          active: currentLocation.startsWith('/admin/users'),
          onTap: () => context.go('/admin/users'),
        ),
        _NavItem(
          icon: Icons.groups_2_outlined,
          label: 'Clubes',
          active: currentLocation.startsWith('/admin/clubs'),
          onTap: () => context.go('/admin/clubs'),
        ),
        _NavItem(
          icon: Icons.flag_outlined,
          label: 'Denúncias',
          active: currentLocation.startsWith('/admin/reports'),
          onTap: () => context.go('/admin/reports'),
        ),
        _NavItem(
          icon: Icons.card_membership_outlined,
          label: 'Assinaturas',
          active: currentLocation.startsWith('/admin/subscriptions'),
          onTap: () => context.go('/admin/subscriptions'),
        ),
        _NavItem(
          icon: Icons.bar_chart_outlined,
          label: 'Métricas',
          active: currentLocation.startsWith('/admin/metrics'),
          onTap: () => context.go('/admin/metrics'),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDrawer extends StatelessWidget {
  final String currentLocation;
  const _AdminDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ReadLogColors.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUMEN',
                    style: ReadLogType.display(
                      size: 20,
                      color: ReadLogColors.inkInverse,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ADMIN PANEL',
                    style: ReadLogType.mono(
                      size: 9,
                      color: ReadLogColors.progress,
                    ).copyWith(letterSpacing: 3),
                  ),
                ],
              ),
            ),
            Divider(color: ReadLogColors.hairlineDark, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                    active: currentLocation == '/admin',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin');
                    },
                  ),
                  _NavItem(
                    icon: Icons.people_outline,
                    label: 'Usuários',
                    active: currentLocation.startsWith('/admin/users'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin/users');
                    },
                  ),
                  _NavItem(
                    icon: Icons.groups_2_outlined,
                    label: 'Clubes',
                    active: currentLocation.startsWith('/admin/clubs'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin/clubs');
                    },
                  ),
                  _NavItem(
                    icon: Icons.flag_outlined,
                    label: 'Denúncias',
                    active: currentLocation.startsWith('/admin/reports'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin/reports');
                    },
                  ),
                  _NavItem(
                    icon: Icons.card_membership_outlined,
                    label: 'Assinaturas',
                    active: currentLocation.startsWith('/admin/subscriptions'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin/subscriptions');
                    },
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Métricas',
                    active: currentLocation.startsWith('/admin/metrics'),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/admin/metrics');
                    },
                  ),
                ],
              ),
            ),
            Divider(color: ReadLogColors.hairlineDark, height: 1),
            _NavItem(
              icon: Icons.arrow_back_outlined,
              label: 'Voltar ao App',
              active: false,
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared item widget
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? ReadLogColors.progress : Colors.transparent,
                width: 3,
              ),
            ),
            color: active
                ? ReadLogColors.inkInverse.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? ReadLogColors.inkInverse
                    : ReadLogColors.inkInverse.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: ReadLogType.mono(
                  size: 13,
                  color: active
                      ? ReadLogColors.inkInverse
                      : ReadLogColors.inkInverse.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
