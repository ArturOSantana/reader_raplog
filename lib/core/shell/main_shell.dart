import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../core/theme/app_theme.dart';

/// Chave global exposta para que telas filhas possam abrir o Drawer do MainShell.
final mainScaffoldKey = GlobalKey<ScaffoldState>();

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(isOnlineProvider, (previous, next) async {
      if (next && _wasOffline) {
        await ref.read(syncServiceProvider).sync();
      }
      _wasOffline = !next;
    });
  }

  static int _locationToIndex(String location) {
    if (location.startsWith('/library')) { return 1; }
    if (location.startsWith('/calendar')) { return 2; }
    if (location.startsWith('/social') ||
        location.startsWith('/friends') ||
        location.startsWith('/clubs')) { return 3; }
    if (location.startsWith('/profile') ||
        location.startsWith('/achievements') ||
        location.startsWith('/goals') ||
        location.startsWith('/wishlist') ||
        location.startsWith('/dashboard')) { return 4; }
    return 0; // /home, /session, /session-history
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/library');
      case 2:
        context.go('/calendar');
      case 3:
        context.go('/social');
      case 4:
        context.go('/profile');
    }
  }

  Future<void> _signOut() async {
    await GoogleSignIn().signOut();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _locationToIndex(location);
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final email = user?.email ?? '';

    return Scaffold(
      key: mainScaffoldKey,
      drawer: _AppDrawer(
        currentLocation: location,
        avatarUrl: avatarUrl,
        fullName: fullName,
        email: email,
        onSignOut: _signOut,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outline,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => _onTap(context, i),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined),
              activeIcon: Icon(Icons.library_books),
              label: 'Biblioteca',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendário',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Social',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final String currentLocation;
  final String? avatarUrl;
  final String? fullName;
  final String email;
  final VoidCallback onSignOut;

  const _AppDrawer({
    required this.currentLocation,
    required this.avatarUrl,
    required this.fullName,
    required this.email,
    required this.onSignOut,
  });

  bool _isActive(String path) => currentLocation.startsWith(path);

  void _navigate(BuildContext context, String path) {
    Navigator.of(context).pop(); // fecha o drawer
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(fullName ?? email);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Cabeçalho do usuário ──────────────────────────────────
            InkWell(
              onTap: () => _navigate(context, '/profile'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                color: AppColors.forestGreen,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: (avatarUrl == null || avatarUrl!.isEmpty)
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fullName != null && fullName!.isNotEmpty)
                            Text(
                              fullName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Itens do menu ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Início',
                    active: _isActive('/home'),
                    onTap: () => _navigate(context, '/home'),
                  ),
                  _DrawerItem(
                    icon: Icons.library_books_outlined,
                    label: 'Biblioteca',
                    active: _isActive('/library'),
                    onTap: () => _navigate(context, '/library'),
                  ),
                  _DrawerItem(
                    icon: Icons.timer_outlined,
                    label: 'Sessão de leitura',
                    active: _isActive('/session'),
                    onTap: () => _navigate(context, '/session'),
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Dashboard',
                    active: _isActive('/dashboard'),
                    onTap: () => _navigate(context, '/dashboard'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.flag_outlined,
                    label: 'Metas',
                    active: _isActive('/goals'),
                    onTap: () => _navigate(context, '/goals'),
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Conquistas',
                    active: _isActive('/achievements'),
                    onTap: () => _navigate(context, '/achievements'),
                  ),
                  _DrawerItem(
                    icon: Icons.bookmark_border,
                    label: 'Lista de desejos',
                    active: _isActive('/wishlist'),
                    onTap: () => _navigate(context, '/wishlist'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendário',
                    active: _isActive('/calendar'),
                    onTap: () => _navigate(context, '/calendar'),
                  ),
                  _DrawerItem(
                    icon: Icons.dynamic_feed_outlined,
                    label: 'Feed social',
                    active: _isActive('/social'),
                    onTap: () => _navigate(context, '/social'),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Amigos',
                    active: _isActive('/friends'),
                    onTap: () => _navigate(context, '/friends'),
                  ),
                  _DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Clubes de leitura',
                    active: _isActive('/clubs'),
                    onTap: () => _navigate(context, '/clubs'),
                  ),
                ],
              ),
            ),

            // ── Rodapé: sair ─────────────────────────────────────────
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sair',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: active ? AppColors.forestGreen : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.forestGreen : AppColors.textPrimary,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      tileColor: active
          ? AppColors.forestGreen.withValues(alpha: 0.08)
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}
