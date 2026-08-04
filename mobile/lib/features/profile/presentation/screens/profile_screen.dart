import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/local/local_database.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../core/shell/main_shell.dart' show openAppDrawer;

// ── Providers ──────────────────────────────────────────────────────────────

final _profileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).fetch();
});

final _profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);
  final achievementRepo = ref.watch(achievementRepositoryProvider);

  final results = await Future.wait([
    sessionRepo.fetchStreak(),
    sessionRepo.fetchPeriodStats(period: 'year'),
    bookRepo.fetchAll(),
    achievementRepo.fetchAll(),
  ]);

  final books = results[2] as List<Book>;
  final achievements = results[3] as List<Achievement>;

  return {
    'streak': (results[0] as num?)?.toInt() ?? 0,
    'yearStats': results[1] as Map<String, dynamic>,
    'books': books,
    'achievements': achievements,
  };
});

final _goalsProvider = FutureProvider<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).fetchAll();
});

final _clubsProvider = FutureProvider<List<BookClub>>((ref) {
  return ref.watch(bookClubRepositoryProvider).listMyClubs();
});

final _friendsCountProvider = FutureProvider<int>((ref) async {
  final friends = await ref.watch(friendsRepositoryProvider).listFriends();
  return friends.length;
});

final _profileHeatmapProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(sessionRepositoryProvider).fetchHeatmap(days: 365);
});

// ══════════════════════════════════════════════════════════════════════════════
// ProfileScreen
// ══════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(_profileProvider);

    final avatarUrl = (profileAsync.valueOrNull?.avatarUrl ?? user?.userMetadata?['avatar_url']) as String?;
    final fullName = profileAsync.valueOrNull?.name ?? user?.userMetadata?['full_name'] as String?;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? LumenColors.canvas : LumenColors.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? LumenColors.canvas : LumenColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          tooltip: 'Menu',
          onPressed: openAppDrawer,
        ),
        title: Text(
          'Perfil',
          style: LumenType.bookTitle(size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: LumenSpace.md, vertical: LumenSpace.md),
        children: [
          // ── Cabeçalho de identidade ────────────────────────────────────────
          _IdentityHeader(
            avatarUrl: avatarUrl,
            fullName: fullName,
            email: email,
            profileAsync: profileAsync,
            onEdit: () => _showEditSheet(context, ref, profileAsync.valueOrNull, fullName, avatarUrl),
          ),

          _divider(),

          // ── Resumo do ano ──────────────────────────────────────────────────
          _SectionCaption(label: 'Resumo do ano'),
          const SizedBox(height: LumenSpace.md),
          const _StatGrid(),

          _divider(),

          // ── Objetivos ──────────────────────────────────────────────────────
          _SectionCaption(label: 'Objetivos'),
          const SizedBox(height: LumenSpace.md),
          const _GoalsSection(),

          _divider(),

          // ── Links de navegação ─────────────────────────────────────────────
          _ClubsLinkRow(onTap: () => context.go('/clubs')),
          _FriendsLinkRow(onTap: () => context.go('/friends')),
          _CalendarLinkRow(onTap: () => context.go('/calendar')),
          _AchievementsLinkRow(onTap: () => context.go('/achievements')),
          _CollectionLinkRow(onTap: () => context.go('/library')),

          _divider(),

          // ── Heatmap de atividade ───────────────────────────────────────────
          _SectionCaption(label: 'Atividade · 365 dias'),
          const SizedBox(height: LumenSpace.md),
          const _HeatmapSection(),

          _divider(),

          // ── Mais ───────────────────────────────────────────────────────────
          _SectionCaption(label: 'Mais'),
          const SizedBox(height: LumenSpace.xs),
          _LinkRow(
            icon: Icons.bar_chart_outlined,
            label: 'Painel',
            onTap: () => context.push('/dashboard'),
          ),
          _LinkRow(
            icon: Icons.flag_outlined,
            label: 'Missões',
            onTap: () => context.push('/goals'),
          ),
          _LinkRow(
            icon: Icons.dynamic_feed_outlined,
            label: 'Feed social',
            onTap: () => context.push('/social'),
          ),
          _LinkRow(
            icon: Icons.favorite_border,
            label: 'Lista de desejos',
            onTap: () => context.push('/wishlist'),
          ),
          _LinkRow(
            icon: Icons.notifications_outlined,
            label: 'Notificações',
            onTap: () => context.push('/notifications'),
          ),
          _LinkRow(
            icon: Icons.settings_outlined,
            label: 'Configurações',
            isLast: true,
            onTap: () => _showSettingsSheet(context, ref),
          ),

          const SizedBox(height: LumenSpace.xl),
        ],
      ),
    );
  }

  // ── Edit sheet ─────────────────────────────────────────────────────────────

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    String? displayName,
    String? avatarUrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? LumenColors.canvas : LumenColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LumenRadius.modal)),
      ),
      builder: (_) => _EditProfileSheet(
        profile: profile,
        displayName: displayName,
        currentAvatarUrl: avatarUrl,
        onSaved: () => ref.invalidate(_profileProvider),
      ),
    );
  }

  // ── Settings sheet ─────────────────────────────────────────────────────────

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? LumenColors.canvas : LumenColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LumenRadius.modal)),
      ),
      builder: (sheetContext) => _SettingsSheet(
        profileAsync: ref.read(_profileProvider),
        onEditProfile: () {
          Navigator.of(sheetContext).pop();
          _showEditSheet(
            context, ref,
            ref.read(_profileProvider).valueOrNull,
            ref.read(currentUserProvider)?.userMetadata?['full_name'] as String?,
            (ref.read(_profileProvider).valueOrNull?.avatarUrl
                ?? ref.read(currentUserProvider)?.userMetadata?['avatar_url']) as String?,
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helpers de layout
// ══════════════════════════════════════════════════════════════════════════════

class _SectionCaption extends StatelessWidget {
  final String label;
  const _SectionCaption({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: LumenType.mono(
        size: 10,
        color: LumenColors.inkMuted,
      ).copyWith(letterSpacing: 1.2),
    );
  }
}

Widget _divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: LumenSpace.lg),
      child: Divider(height: 1, thickness: 1, color: LumenColors.divider),
    );

String _monthYear(DateTime date) {
  const months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];
  return '${months[date.month - 1]} de ${date.year}';
}

String _formatNumber(int n) {
  if (n >= 1000) {
    final s = n.toString();
    final rest = s.substring(s.length - 3);
    final head = s.substring(0, s.length - 3);
    return '$head.$rest';
  }
  return '$n';
}

// ══════════════════════════════════════════════════════════════════════════════
// _IdentityHeader
// ══════════════════════════════════════════════════════════════════════════════

class _IdentityHeader extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final String email;
  final AsyncValue<UserProfile?> profileAsync;
  final VoidCallback onEdit;

  const _IdentityHeader({
    required this.avatarUrl,
    required this.fullName,
    required this.email,
    required this.profileAsync,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull;
    final displayName = profile?.name ?? fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(url: avatarUrl, name: displayName ?? email),
        const SizedBox(height: LumenSpace.md),

        if (displayName != null && displayName.isNotEmpty)
          Text(
            displayName,
            style: LumenType.bookTitle(size: 20),
          ),

        const SizedBox(height: 4),
        Text(
          email,
          style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
        ),

        // Bio
        if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
          const SizedBox(height: LumenSpace.sm),
          Text(
            '"${profile.bio!}"',
            style: LumenType.quote(size: 13, color: LumenColors.inkMuted),
          ),
        ],

        // Membro desde
        if (profile != null) ...[
          const SizedBox(height: LumenSpace.sm),
          Text(
            'Membro desde ${_monthYear(profile.updatedAt)}',
            style: LumenType.mono(size: 10, color: LumenColors.inkMuted)
                .copyWith(letterSpacing: 0.4),
          ),
        ],

        // Editar perfil
        const SizedBox(height: LumenSpace.md),
        GestureDetector(
          onTap: onEdit,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 13, color: LumenColors.warning),
              const SizedBox(width: 5),
              Text(
                'Editar perfil',
                style: LumenType.mono(size: 12, color: LumenColors.warning),
              ),
            ],
          ),
        ),

        // Identidade: gênero + autores + livro favorito
        if (profile != null) ...[
          const SizedBox(height: LumenSpace.md),
          if (profile.favoriteGenre?.trim().isNotEmpty == true) ...[
            _GenreChip(label: profile.favoriteGenre!.trim()),
            const SizedBox(height: LumenSpace.sm),
          ],
          if (profile.favoriteAuthors?.trim().isNotEmpty == true)
            _IdentityLine(
              icon: Icons.person_outline,
              text: profile.favoriteAuthors!.trim(),
              prefix: 'Autores favoritos: ',
            ),
          if (profile.favoriteBook?.trim().isNotEmpty == true)
            _IdentityLine(
              icon: Icons.menu_book_outlined,
              text: profile.favoriteBook!.trim(),
              prefix: 'Livro favorito: ',
            ),
        ],
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: LumenColors.warning),
        borderRadius: BorderRadius.circular(LumenRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: LumenType.mono(size: 9, color: LumenColors.warning)
            .copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  final IconData icon;
  final String prefix;
  final String text;

  const _IdentityLine({
    required this.icon,
    required this.prefix,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LumenSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: LumenColors.inkMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
                children: [
                  TextSpan(text: prefix),
                  TextSpan(
                    text: text,
                    style: LumenType.mono(size: 11, color: LumenColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StatGrid — grade 3×2, número Fraunces grande, sem ícone
// ══════════════════════════════════════════════════════════════════════════════

class _StatGrid extends ConsumerWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Text(
        'Não foi possível carregar.',
        style: LumenType.mono(size: 12, color: LumenColors.inkMuted),
      ),
      data: (stats) {
        final books = stats['books'] as List<Book>;
        final streak = stats['streak'] as int;
        final yearStats = stats['yearStats'] as Map<String, dynamic>;
        final achievements = stats['achievements'] as List<Achievement>;

        final readBooks = books.where((b) => b.status == BookStatus.read).length;
        final totalMinutes = (yearStats['total_minutes'] as int? ?? 0);
        final totalPages = (yearStats['total_pages'] as int? ?? 0);
        final unlockedAchievements = achievements.where((a) => a.isUnlocked).length;
        final totalAchievements = achievements.length;
        final hours = totalMinutes ~/ 60;

        final currentBook = books.where((b) => b.status == BookStatus.reading).firstOrNull;
        final currentPageStr = currentBook?.currentPage != null
            ? '${currentBook!.currentPage}'
            : '—';

        return _StatGridLayout(
          items: [
            _StatItem(value: '$streak', label: 'dias de sequência'),
            _StatItem(value: '$readBooks', label: 'livros concluídos'),
            _StatItem(value: currentPageStr, label: 'pág. atual'),
            _StatItem(value: '${hours}h', label: 'tempo total'),
            _StatItem(value: _formatNumber(totalPages), label: 'páginas lidas'),
            _StatItem(
              value: '$unlockedAchievements${totalAchievements > 0 ? '/$totalAchievements' : ''}',
              label: 'conquistas',
            ),
          ],
        );
      },
    );
  }
}

class _StatGridLayout extends StatelessWidget {
  final List<_StatItem> items;
  const _StatGridLayout({required this.items});

  @override
  Widget build(BuildContext context) {
    final cols = 3;
    final rows = <Widget>[];
    for (var r = 0; r < (items.length / cols).ceil(); r++) {
      final rowItems = <Widget>[];
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        rowItems.add(
          Expanded(
            child: idx < items.length
                ? items[idx].build(context)
                : const SizedBox(),
          ),
        );
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems));
      if (r < (items.length / cols).ceil() - 1) rows.add(const SizedBox(height: LumenSpace.lg));
    }
    return Column(children: rows);
  }
}

class _StatItem {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: LumenType.bookTitle(size: 24, weight: FontWeight.w400),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: LumenType.mono(size: 8, color: LumenColors.inkMuted)
              .copyWith(letterSpacing: 0.4),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _GoalsSection — linha fina + ponto (LumenReadingProgress)
// ══════════════════════════════════════════════════════════════════════════════

class _GoalsSection extends ConsumerWidget {
  const _GoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_goalsProvider);
    final statsAsync = ref.watch(_profileStatsProvider);
    final profileAsync = ref.watch(_profileProvider);

    return goalsAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Text(
        'Não foi possível carregar.',
        style: LumenType.mono(size: 12, color: LumenColors.inkMuted),
      ),
      data: (goals) {
        final yearStats = statsAsync.valueOrNull?['yearStats'] as Map<String, dynamic>?;
        final books = statsAsync.valueOrNull?['books'] as List<Book>?;
        final readBooks = books?.where((b) => b.status == BookStatus.read).length ?? 0;
        final totalPagesYear = (yearStats?['total_pages'] as int?) ?? 0;
        final totalMinutesYear = (yearStats?['total_minutes'] as int?) ?? 0;
        final now = DateTime.now();
        final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

        // Fallback: meta anual do perfil
        if (goals.isEmpty) {
          final yearlyGoal = profileAsync.valueOrNull?.yearlyGoal;
          if (yearlyGoal != null && yearlyGoal > 0) {
            return _GoalRow(
              label: 'Livros no ano',
              current: readBooks,
              total: yearlyGoal,
              unit: 'livros',
            );
          }
          return Text(
            'Nenhuma meta definida.',
            style: LumenType.mono(size: 12, color: LumenColors.inkMuted),
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < goals.length; i++) {
          final goal = goals[i];
          int current = 0;
          switch (goal.type) {
            case GoalType.yearlyBooks:
              current = readBooks;
              break;
            case GoalType.monthlyPages:
              current = totalPagesYear;
              break;
            case GoalType.dailyPages:
              current = dayOfYear > 0 ? (totalPagesYear ~/ dayOfYear) : 0;
              break;
            case GoalType.dailyMinutes:
              current = dayOfYear > 0 ? (totalMinutesYear ~/ dayOfYear) : 0;
              break;
          }
          if (i > 0) rows.add(const SizedBox(height: LumenSpace.md));
          rows.add(_GoalRow(
            label: goal.type.label,
            current: current,
            total: goal.targetValue,
            unit: goal.type.unit,
          ));
        }
        return Column(children: rows);
      },
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  final String unit;

  const _GoalRow({
    required this.label,
    required this.current,
    required this.total,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: LumenType.mono(size: 12, color: LumenColors.inkMuted),
            ),
            Text.rich(
              TextSpan(
                style: LumenType.mono(size: 11, color: LumenColors.inkMuted),
                children: [
                  TextSpan(
                    text: '$current',
                    style: LumenType.mono(size: 11, color: LumenColors.ink),
                  ),
                  TextSpan(text: ' de $total'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: LumenSpace.sm),
        LumenReadingProgress(progress: pct),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LinkRow genérico — label + ícone + valor + chevron
// ══════════════════════════════════════════════════════════════════════════════

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isLast;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? LumenColors.inkInverse : LumenColors.ink;
    final iconColor = isDark ? LumenColors.inkMutedInverse : LumenColors.inkMuted;
    final dividerColor = isDark ? LumenColors.dividerDark : LumenColors.divider;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: LumenSpace.sm),
            Expanded(
              child: Text(
                label,
                style: LumenType.mono(size: 13, color: textColor),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: LumenType.mono(size: 11, color: iconColor),
              ),
              const SizedBox(width: 5),
            ],
            Icon(Icons.chevron_right, size: 14, color: iconColor),
          ],
        ),
      ),
    );
  }
}

// ── Link rows com dados reais ──────────────────────────────────────────────

class _ClubsLinkRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _ClubsLinkRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(_clubsProvider);
    final value = clubsAsync.whenOrNull(
      data: (clubs) => '${clubs.length} participando',
    );
    return _LinkRow(icon: Icons.groups_outlined, label: 'Clubes', value: value, onTap: onTap);
  }
}

class _FriendsLinkRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _FriendsLinkRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_friendsCountProvider);
    final value = countAsync.whenOrNull(data: (n) => '$n');
    return _LinkRow(icon: Icons.person_outline, label: 'Amigos', value: value, onTap: onTap);
  }
}

class _CalendarLinkRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _CalendarLinkRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(_profileHeatmapProvider);
    final value = heatmapAsync.whenOrNull(
      data: (heatmap) {
        final activeDays = heatmap.where((e) => ((e['total_minutes'] as num?) ?? 0) > 0).length;
        return '$activeDays dias ativos';
      },
    );
    return _LinkRow(icon: Icons.calendar_today_outlined, label: 'Calendário', value: value, onTap: onTap);
  }
}

class _AchievementsLinkRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _AchievementsLinkRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);
    final value = statsAsync.whenOrNull(
      data: (stats) {
        final achievements = stats['achievements'] as List<Achievement>;
        final unlocked = achievements.where((a) => a.isUnlocked).length;
        return '$unlocked de ${achievements.length}';
      },
    );
    return _LinkRow(
      icon: Icons.workspace_premium_outlined,
      label: 'Conquistas recentes',
      value: value,
      onTap: onTap,
    );
  }
}

class _CollectionLinkRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _CollectionLinkRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);
    final value = statsAsync.whenOrNull(
      data: (stats) {
        final books = stats['books'] as List<Book>;
        return '${books.length} livros';
      },
    );
    return _LinkRow(
      icon: Icons.local_library_outlined,
      label: 'Coleção',
      value: value,
      isLast: true,
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HeatmapSection — monocromático, variação só de opacidade
// ══════════════════════════════════════════════════════════════════════════════

class _HeatmapSection extends ConsumerWidget {
  const _HeatmapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(_profileHeatmapProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? LumenColors.inkInverse : LumenColors.ink;

    return heatmapAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (heatmap) {
        // Normaliza para intensidade 0–3
        final data = <String, int>{
          for (final e in heatmap)
            (e['date'] as String? ?? ''): (e['total_minutes'] as num?)?.toInt() ?? 0,
        };

        // Gera lista de 365 dias mais recentes
        final today = DateTime.now();
        final intensities = List.generate(365, (i) {
          final date = today.subtract(Duration(days: 364 - i));
          final key =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final minutes = data[key] ?? 0;
          if (minutes == 0) return 0;
          if (minutes < 10) return 1;
          if (minutes < 30) return 2;
          return 3;
        });

        const columns = 26;
        const opacities = [0.06, 0.22, 0.42, 0.70];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: intensities.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (_, i) {
            final level = intensities[i].clamp(0, 3);
            return Container(
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: opacities[level]),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _Avatar / _InitialsAvatar
// ══════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: LumenColors.surfaceVariant,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials, radius: 28),
          ),
        ),
      );
    }

    return _InitialsAvatar(initials: initials, radius: 28);
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;

  const _InitialsAvatar({required this.initials, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: LumenColors.ink,
      child: Text(
        initials,
        style: TextStyle(
          color: LumenColors.surface,
          fontSize: radius * 0.58,
          fontWeight: FontWeight.w500,
          fontFamily: 'Fraunces',
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SettingsSheet
// ══════════════════════════════════════════════════════════════════════════════

class _SettingsSheet extends ConsumerWidget {
  final AsyncValue<UserProfile?> profileAsync;
  final VoidCallback onEditProfile;

  const _SettingsSheet({
    required this.profileAsync,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: LumenSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Configurações',
                style: LumenType.bookTitle(size: 18, color: cs.onSurface),
              ),
            ),
          ),
          _settingsTile(
            context,
            icon: Icons.edit_outlined,
            label: 'Editar Perfil',
            onTap: onEditProfile,
          ),
          _settingsTile(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notificações',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/notifications/settings');
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: LumenSpace.sm),
          ListTile(
            leading: Icon(Icons.logout_outlined, size: 20, color: LumenColors.danger),
            title: Text(
              'Sair',
              style: LumenType.mono(size: 13, color: LumenColors.danger),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: LumenSpace.sm),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20, color: cs.onSurface),
      title: Text(label, style: LumenType.mono(size: 13, color: cs.onSurface)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: onTap,
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sheetNavigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sair', style: LumenType.bookTitle(size: 16, color: cs.onSurface)),
        content: Text(
          'Tem certeza que deseja sair da sua conta?',
          style: LumenType.mono(size: 13, color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar', style: LumenType.mono(size: 13, color: cs.onSurface)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              sheetNavigator.pop();
              _performSignOut(ref);
            },
            child: Text('Sair', style: LumenType.mono(size: 13, color: LumenColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOut(WidgetRef ref) async {
    await LocalDatabase.instance.clearUserData();
    ref.invalidate(bookRepositoryProvider);
    ref.invalidate(sessionRepositoryProvider);
    ref.invalidate(noteRepositoryProvider);
    ref.invalidate(profileRepositoryProvider);
    ref.invalidate(onboardingCompletedProvider);
    await GoogleSignIn().signOut();
    await Supabase.instance.client.auth.signOut();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EditProfileSheet
// ══════════════════════════════════════════════════════════════════════════════

class _EditProfileSheet extends StatefulWidget {
  final UserProfile? profile;
  final String? displayName;
  final String? currentAvatarUrl;
  final VoidCallback onSaved;

  const _EditProfileSheet({
    required this.profile,
    required this.displayName,
    required this.currentAvatarUrl,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _yearlyGoalController;
  late final TextEditingController _genreController;
  late final TextEditingController _authorsController;
  late final TextEditingController _favoriteBookController;
  bool _loading = false;
  String? _errorMessage;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? widget.displayName ?? '');
    _bioController = TextEditingController(text: widget.profile?.bio ?? '');
    _yearlyGoalController = TextEditingController(text: widget.profile?.yearlyGoal?.toString() ?? '');
    _genreController = TextEditingController(text: widget.profile?.favoriteGenre ?? '');
    _authorsController = TextEditingController(text: widget.profile?.favoriteAuthors ?? '');
    _favoriteBookController = TextEditingController(text: widget.profile?.favoriteBook ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _yearlyGoalController.dispose();
    _genreController.dispose();
    _authorsController.dispose();
    _favoriteBookController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 512);
      if (xFile != null && mounted) {
        setState(() => _pickedImage = File(xFile.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar a câmera ou galeria.')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      String? avatarUrl = widget.profile?.avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ref.read(profileRepositoryProvider).uploadAvatar(_pickedImage!);
      }
      await ref.read(profileRepositoryProvider).upsert({
        'name': _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'yearly_goal': int.tryParse(_yearlyGoalController.text.trim()),
        'favorite_genre': _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        'favorite_authors': _authorsController.text.trim().isEmpty ? null : _authorsController.text.trim(),
        'favorite_book': _favoriteBookController.text.trim().isEmpty ? null : _favoriteBookController.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Erro ao salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _Avatar._initials(
      widget.profile?.name ?? widget.displayName ?? widget.currentAvatarUrl ?? '?',
    );
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: EdgeInsets.only(
          left: LumenSpace.lg, right: LumenSpace.lg, top: LumenSpace.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + LumenSpace.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editar perfil', style: LumenType.bookTitle(size: 18)),
                const SizedBox(height: LumenSpace.lg),
                // ── Avatar picker ────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: LumenColors.surfaceVariant,
                          child: _pickedImage != null
                              ? ClipOval(child: Image.file(_pickedImage!, width: 88, height: 88, fit: BoxFit.cover))
                              : (widget.currentAvatarUrl != null && widget.currentAvatarUrl!.isNotEmpty)
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: widget.currentAvatarUrl!,
                                        width: 88, height: 88, fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials, radius: 44),
                                      ),
                                    )
                                  : _InitialsAvatar(initials: initials, radius: 44),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: LumenColors.ink,
                              shape: BoxShape.circle,
                              border: Border.all(color: LumenColors.surface, width: 2),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: Icon(Icons.camera_alt, size: 14, color: LumenColors.surface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LumenSpace.lg),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome de exibição'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: LumenSpace.md),
                TextFormField(
                  controller: _bioController,
                  maxLines: 2,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Biografia (opcional)'),
                ),
                const SizedBox(height: LumenSpace.xs),
                TextFormField(
                  controller: _yearlyGoalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Missão anual de livros'),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Informe um número maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: LumenSpace.md),
                TextFormField(
                  controller: _genreController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Gênero favorito (opcional)'),
                ),
                const SizedBox(height: LumenSpace.md),
                TextFormField(
                  controller: _favoriteBookController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Livro favorito (opcional)'),
                ),
                const SizedBox(height: LumenSpace.md),
                TextFormField(
                  controller: _authorsController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Autores favoritos (opcional)'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: LumenSpace.md),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: LumenColors.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: LumenSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : () => _save(ref),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
