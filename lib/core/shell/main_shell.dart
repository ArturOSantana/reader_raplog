import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../theme/readlog_theme.dart';
import '../../theme/readlog_components.dart';
import '../../features/session/presentation/notifiers/session_notifier.dart';

final mainScaffoldKey = GlobalKey<ScaffoldState>();

/// Abre o drawer global de qualquer lugar do app.
void openAppDrawer() => mainScaffoldKey.currentState?.openDrawer();

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
    // Registra o ScaffoldKey para que ReadLogPageHeader possa abrir o Drawer.
    registerAppScaffoldKey(mainScaffoldKey);
    ref.listenManual(isOnlineProvider, (previous, next) async {
      if (next && _wasOffline) {
        await ref.read(syncServiceProvider).sync();
      }
      _wasOffline = !next;
    });
  }

  /// Índices v2: 0=Home, 1=Clubs, 2=Session, 3=Library, 4=Profile
  static int _locationToIndex(String location) {
    if (location.startsWith('/clubs'))    { return 1; }
    if (location.startsWith('/session'))  { return 2; }
    if (location.startsWith('/library'))  { return 3; }
    if (location.startsWith('/profile')    ||
        location.startsWith('/goals')      ||
        location.startsWith('/wishlist')   ||
        location.startsWith('/dashboard')  ||
        location.startsWith('/calendar')   ||
        location.startsWith('/social')     ||
        location.startsWith('/friends')    ||
        location.startsWith('/achievements') ||
        location.startsWith('/notifications')) { return 4; }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/clubs');
      case 2: context.go('/session');
      case 3: context.go('/library');
      case 4: context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location      = GoRouterState.of(context).matchedLocation;
    final index         = _locationToIndex(location);
    final sessionState  = ref.watch(sessionNotifierProvider);
    final sessionActive = sessionState.hasActiveSession;
    // Não mostrar ribbon se já estamos dentro da tela de sessão
    final showRibbon    = sessionActive && !location.startsWith('/session');

    // Formata segundos → "HH:MM:SS"
    String fmtElapsed(int s) {
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      final sec = s % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      key: mainScaffoldKey,
      drawer: _AppDrawer(currentLocation: location),
      body: Column(
        children: [
          const OfflineBanner(),
          if (showRibbon)
            ReadLogSessionRibbon(
              bookTitle: 'Em leitura',
              elapsed: fmtElapsed(sessionState.elapsedSeconds),
              onTap: () => context.go('/session'),
            ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: ReadLogSpineNavBar(
        currentIndex: index,
        sessionActive: sessionActive,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer global
// ─────────────────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  final String currentLocation;
  const _AppDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = user?.userMetadata?['full_name'] as String?;
    final email = user?.email ?? '';
    final name = fullName ?? email;
    final initials = name.trim().split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2).join().toUpperCase();

    void go(String route) {
      Navigator.of(context).pop(); // fecha o drawer
      context.go(route);
    }

    void push(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Drawer(
      backgroundColor: ReadLogColors.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Identidade ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => go('/profile'),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ReadLogColors.brass,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: ReadLogType.mono(
                          size: 16,
                          weight: FontWeight.w700,
                          color: ReadLogColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName != null)
                          Text(fullName,
                              style: ReadLogType.display(
                                size: 15,
                                color: ReadLogColors.cream,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        Text(email,
                            style: ReadLogType.mono(
                              size: 11,
                              color: ReadLogColors.cream.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: ReadLogColors.cream, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              color: ReadLogColors.cream.withValues(alpha: 0.1),
              height: 1,
            ),
            // ── Navegação principal ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _DrawerSection(label: 'PRINCIPAL'),
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    active: currentLocation == '/home',
                    onTap: () => go('/home'),
                  ),
                  _DrawerTile(
                    icon: Icons.groups_2_outlined,
                    label: 'Clubes de Leitura',
                    active: currentLocation.startsWith('/clubs'),
                    onTap: () => go('/clubs'),
                  ),
                  _DrawerTile(
                    icon: Icons.play_circle_outline,
                    label: 'Sessão de Leitura',
                    active: currentLocation.startsWith('/session'),
                    onTap: () => go('/session'),
                  ),
                  _DrawerTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Biblioteca',
                    active: currentLocation.startsWith('/library'),
                    onTap: () => go('/library'),
                  ),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    active: currentLocation == '/profile',
                    onTap: () => go('/profile'),
                  ),
                  const SizedBox(height: 8),
                  _DrawerSection(label: 'FERRAMENTAS'),
                  _DrawerTile(
                    icon: Icons.flag_outlined,
                    label: 'Missões',
                    active: currentLocation.startsWith('/goals'),
                    onTap: () => push('/goals'),
                  ),
                  _DrawerTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Painel de Estatísticas',
                    active: currentLocation.startsWith('/dashboard'),
                    onTap: () => push('/dashboard'),
                  ),
                  _DrawerTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendário',
                    active: currentLocation.startsWith('/calendar'),
                    onTap: () => push('/calendar'),
                  ),
                  _DrawerTile(
                    icon: Icons.dynamic_feed_outlined,
                    label: 'Feed Social',
                    active: currentLocation.startsWith('/social'),
                    onTap: () => push('/social'),
                  ),
                  _DrawerTile(
                    icon: Icons.people_outline,
                    label: 'Amigos',
                    active: currentLocation.startsWith('/friends'),
                    onTap: () => push('/friends'),
                  ),
                  _DrawerTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'Conquistas',
                    active: currentLocation.startsWith('/achievements'),
                    onTap: () => push('/achievements'),
                  ),
                  _DrawerTile(
                    icon: Icons.bookmark_border,
                    label: 'Lista de Desejos',
                    active: currentLocation.startsWith('/wishlist'),
                    onTap: () => push('/wishlist'),
                  ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notificações',
                    active: currentLocation.startsWith('/notifications'),
                    onTap: () => push('/notifications'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label,
        style: ReadLogType.mono(
          size: 9,
          color: ReadLogColors.brass,
        ).copyWith(letterSpacing: 2),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DrawerTile({
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? ReadLogColors.stamp : Colors.transparent,
                width: 3,
              ),
            ),
            color: active
                ? ReadLogColors.cream.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? ReadLogColors.cream
                    : ReadLogColors.cream.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: ReadLogType.mono(
                  size: 13,
                  color: active
                      ? ReadLogColors.cream
                      : ReadLogColors.cream.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
