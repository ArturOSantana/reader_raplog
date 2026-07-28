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
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/models/achievement.dart';
import '../../../../shared/models/book_club.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../theme/readlog_components.dart';
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
    'streak': results[0] as int,
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
      backgroundColor: ReadLogColors.paperAlt,
      appBar: AppBar(
        backgroundColor: ReadLogColors.paperAlt,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22, color: ReadLogColors.charcoal),
          tooltip: 'Menu',
          onPressed: openAppDrawer,
        ),
        title: Text('Perfil',
            style: ReadLogType.display(
                size: 18, color: ReadLogColors.charcoal, weight: FontWeight.w600)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Cabeçalho de identidade ──────────────────────────────────────
          _IdentityCard(
            avatarUrl: avatarUrl,
            fullName: fullName,
            email: email,
            profileAsync: profileAsync,
            onEdit: () => _showEditSheet(context, ref, profileAsync.valueOrNull, fullName, avatarUrl),
          ),

          _sectionGap(),

          // ── Resumo ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Resumo'),
          const _SummaryGrid(),

          _sectionGap(),

          // ── Objetivos ────────────────────────────────────────────────────
          _SectionHeader(label: 'Objetivos'),
          const _GoalsCard(),

          _sectionGap(),

          // ── Preferências de leitura (só exibe se houver gênero definido) ─
          if (profileAsync.valueOrNull?.favoriteGenre?.trim().isNotEmpty == true) ...[
            _SectionHeader(label: 'Preferências de Leitura'),
            _PreferencesCard(profileAsync: profileAsync),
            _sectionGap(),
          ],

          // ── Autores favoritos (só exibe se houver dados) ─────────────────
          if ((profileAsync.valueOrNull?.favoriteAuthors ?? '').trim().isNotEmpty) ...[
            _SectionHeader(label: 'Autores Favoritos'),
            _FavoriteAuthorsCard(profileAsync: profileAsync),
            _sectionGap(),
          ],

          // ── Livros favoritos (só exibe se houver dados) ──────────────────
          if (profileAsync.valueOrNull?.favoriteBook?.trim().isNotEmpty == true) ...[
            _SectionHeader(label: 'Livros Favoritos'),
            _FavoriteBooksCard(profileAsync: profileAsync),
            _sectionGap(),
          ],

          // ── Clube do livro ───────────────────────────────────────────────
          _SectionHeader(label: 'Clubes'),
          _ClubsCard(onTap: () => context.go('/clubs')),

          _sectionGap(),

          // ── Amigos ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Amigos'),
          _FriendsCard(onTap: () => context.go('/friends')),

          _sectionGap(),

          // ── Calendário ───────────────────────────────────────────────────
          _SectionHeader(label: 'Calendário'),
          _CalendarCard(onTap: () => context.go('/calendar')),

          _sectionGap(),

          // ── Conquistas recentes ──────────────────────────────────────────
          _SectionHeader(label: 'Conquistas Recentes'),
          _RecentAchievementsCard(onTap: () => context.go('/achievements')),

          _sectionGap(),

          // ── Coleção ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Coleção'),
          _CollectionCard(onTap: () => context.go('/library')),

          _sectionGap(),

          // ── Heatmap de atividade ─────────────────────────────────────────
          _SectionHeader(label: 'Atividade — 365 dias'),
          _ActivityHeatmapCard(),

          _sectionGap(),

          // ── Grade de atalhos — seções que não têm aba própria ────────────
          _SectionHeader(label: 'Mais'),
          _QuickLinksGrid(
            links: [
              _QuickLink(
                icon: Icons.bar_chart_outlined,
                label: 'Painel',
                onTap: () => context.push('/dashboard'),
              ),
              _QuickLink(
                icon: Icons.flag_outlined,
                label: 'Missões',
                onTap: () => context.push('/goals'),
              ),
              _QuickLink(
                icon: Icons.dynamic_feed_outlined,
                label: 'Feed Social',
                onTap: () => context.push('/social'),
              ),
              _QuickLink(
                icon: Icons.bookmark_border,
                label: 'Desejos',
                onTap: () => context.push('/wishlist'),
              ),
              _QuickLink(
                icon: Icons.notifications_outlined,
                label: 'Notificações',
                onTap: () => context.push('/notifications'),
              ),
              _QuickLink(
                icon: Icons.calendar_month_outlined,
                label: 'Calendário',
                onTap: () => context.push('/calendar'),
              ),
              _QuickLink(
                icon: Icons.settings_outlined,
                label: 'Config.',
                onTap: () => _showSettingsSheet(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionGap() => const SizedBox(height: 20);

  // ── Edit sheet ────────────────────────────────────────────────────────────

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
      backgroundColor: ReadLogColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditProfileSheet(
        profile: profile,
        displayName: displayName,
        currentAvatarUrl: avatarUrl,
        onSaved: () => ref.invalidate(_profileProvider),
      ),
    );
  }

  // ── Settings sheet ────────────────────────────────────────────────────────

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReadLogColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SettingsSheet(
        profileAsync: ref.read(_profileProvider),
        onEditProfile: () {
          Navigator.pop(context);
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

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: ReadLogType.mono(
          size: 10,
          color: ReadLogColors.charcoal.withValues(alpha: 0.45),
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ReadLogColors.cream,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ReadLogColors.paperDeep.withValues(alpha: 0.5)),
    ),
    child: child,
  );
}

Widget _divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: ReadLogColors.paperDeep.withValues(alpha: 0.5),
      ),
    );

String _monthYear(DateTime date) {
  const months = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];
  return '${months[date.month - 1]}/${date.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// _IdentityCard
// ══════════════════════════════════════════════════════════════════════════════

class _IdentityCard extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final String email;
  final AsyncValue<UserProfile?> profileAsync;
  final VoidCallback onEdit;

  const _IdentityCard({
    required this.avatarUrl,
    required this.fullName,
    required this.email,
    required this.profileAsync,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _Avatar(url: avatarUrl, name: (profileAsync.valueOrNull?.name ?? fullName ?? email)),
          const SizedBox(height: 12),
          if ((profileAsync.valueOrNull?.name ?? fullName) != null &&
              (profileAsync.valueOrNull?.name ?? fullName)!.isNotEmpty)
            Text(
              (profileAsync.valueOrNull?.name ?? fullName)!,
              style: ReadLogType.display(size: 22, color: ReadLogColors.charcoal),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
          Text(
            email,
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.5)),
          ),
          profileAsync.when(
            loading: () => const SizedBox(height: 8),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${profile.bio!}"',
                        style: ReadLogType.mono(
                          size: 12,
                          color: ReadLogColors.charcoal.withValues(alpha: 0.65),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: ReadLogColors.brass),
                        const SizedBox(width: 5),
                        Text(
                          'Membro desde ${_monthYear(profile.updatedAt)}',
                          style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Editar Perfil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ReadLogColors.ink,
              side: BorderSide(color: ReadLogColors.paperDeep),
              textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SummaryGrid — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryGrid extends ConsumerWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);

    return statsAsync.when(
      loading: () => _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Não foi possível carregar.',
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
        ),
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

        // Livro em leitura atual
        final currentBook = books.where((b) => b.status == BookStatus.reading).firstOrNull;
        final currentPageStr = currentBook != null && currentBook.currentPage != null && currentBook.totalPages != null
            ? '${currentBook.currentPage}/${currentBook.totalPages}'
            : currentBook != null
                ? '—'
                : '—';

        final hours = totalMinutes ~/ 60;

        return _card(
          child: Wrap(
            spacing: 0,
            runSpacing: 0,
            children: [
              _SummaryTile(icon: Icons.local_fire_department_outlined, label: 'Ofensiva\natual', value: '$streak dias'),
              _SummaryTile(icon: Icons.menu_book_outlined, label: 'Livros\nconcluídos', value: '$readBooks'),
              _SummaryTile(icon: Icons.import_contacts_outlined, label: 'Página\natual', value: currentPageStr),
              _SummaryTile(icon: Icons.timer_outlined, label: 'Tempo\ntotal', value: '${hours}h'),
              _SummaryTile(icon: Icons.description_outlined, label: 'Páginas\nlidas', value: _formatNumber(totalPages)),
              _SummaryTile(icon: Icons.military_tech_outlined, label: 'Conquistas', value: '$unlockedAchievements'),
            ],
          ),
        );
      },
    );
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
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 40 - 32) / 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, size: 22, color: ReadLogColors.brass),
            const SizedBox(height: 6),
            Text(
              value,
              style: ReadLogType.display(size: 16, color: ReadLogColors.charcoal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: ReadLogType.mono(size: 10, color: ReadLogColors.charcoal.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _GoalsCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _GoalsCard extends ConsumerWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_goalsProvider);
    final statsAsync = ref.watch(_profileStatsProvider);
    final profileAsync = ref.watch(_profileProvider);

    return goalsAsync.when(
      loading: () => _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _card(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Não foi possível carregar.',
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
        ),
      ),
      data: (goals) {
        if (goals.isEmpty) {
          // Tenta mostrar meta anual do perfil se não há goals cadastradas no DB
          final yearlyGoal = profileAsync.valueOrNull?.yearlyGoal;
          final books = statsAsync.valueOrNull?['books'] as List<Book>?;
          final readBooks = books?.where((b) => b.status == BookStatus.read).length ?? 0;

          if (yearlyGoal != null && yearlyGoal > 0) {
            return _card(
              child: _GoalRow(
                label: 'Missão anual',
                current: readBooks,
                total: yearlyGoal,
                unit: 'livros',
              ),
            );
          }
          return _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Nenhuma meta definida. Configure suas metas no painel.',
                style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
              ),
            ),
          );
        }

        final yearStats = statsAsync.valueOrNull?['yearStats'] as Map<String, dynamic>?;
        final books = statsAsync.valueOrNull?['books'] as List<Book>?;
        final readBooks = books?.where((b) => b.status == BookStatus.read).length ?? 0;
        final totalPagesYear = (yearStats?['total_pages'] as int?) ?? 0;
        final totalMinutesYear = (yearStats?['total_minutes'] as int?) ?? 0;
        final now = DateTime.now();
        final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

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
              // Usa total de páginas no ano dividido pelo número de dias para aproximar
              current = dayOfYear > 0 ? (totalPagesYear ~/ dayOfYear) : 0;
              break;
            case GoalType.dailyMinutes:
              current = dayOfYear > 0 ? (totalMinutesYear ~/ dayOfYear) : 0;
              break;
          }
          rows.add(_GoalRow(
            label: goal.type.label,
            current: current,
            total: goal.targetValue,
            unit: goal.type.unit,
          ));
          if (i < goals.length - 1) rows.add(_divider());
        }

        return _card(
          child: Column(children: rows),
        );
      },
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  final String unit;

  const _GoalRow({required this.label, required this.current, required this.total, required this.unit});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.65))),
            Text(
              '$current / $total $unit',
              style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: ReadLogColors.paperDeep.withValues(alpha: 0.5),
            color: ReadLogColors.stamp,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PreferencesCard — gênero favorito vem do perfil real
// ══════════════════════════════════════════════════════════════════════════════

class _PreferencesCard extends StatelessWidget {
  final AsyncValue<UserProfile?> profileAsync;

  const _PreferencesCard({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gênero favorito',
            style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 10),
          profileAsync.when(
            loading: () => Text(
              'Carregando...',
              style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
            ),
            error: (_, __) => Text(
              'Não foi possível carregar.',
              style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
            ),
            data: (profile) {
              final genre = profile?.favoriteGenre?.trim();
              if (genre == null || genre.isEmpty) {
                return Text(
                  'Defina seu gênero favorito no onboarding ou edite seu perfil.',
                  style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [_GenreChip(label: genre)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;

  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ReadLogColors.brass.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ReadLogColors.brass.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_outline, size: 11, color: ReadLogColors.brass),
          const SizedBox(width: 4),
          Text(
            label,
            style: ReadLogType.mono(size: 11, color: ReadLogColors.charcoal.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _FavoriteAuthorsCard
// ══════════════════════════════════════════════════════════════════════════════

class _FavoriteAuthorsCard extends StatelessWidget {
  final AsyncValue<UserProfile?> profileAsync;

  const _FavoriteAuthorsCard({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: profileAsync.when(
        loading: () => Text(
          'Carregando...',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
        ),
        error: (_, __) => Text(
          'Não foi possível carregar.',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
        ),
        data: (profile) {
          final authors = (profile?.favoriteAuthors ?? '')
              .split(',')
              .map((author) => author.trim())
              .where((author) => author.isNotEmpty)
              .toList();
          if (authors.isEmpty) {
            return Text(
              'Adicione autores favoritos no seu perfil.',
              style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
            );
          }
          return Column(
            children: [
              ...authors.asMap().entries.map((e) {
                final isLast = e.key == authors.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: ReadLogColors.brass),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value,
                              style: ReadLogType.mono(size: 13, color: ReadLogColors.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, thickness: 1, color: ReadLogColors.paperDeep.withValues(alpha: 0.5)),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _FavoriteBooksCard
// ══════════════════════════════════════════════════════════════════════════════

class _FavoriteBooksCard extends StatelessWidget {
  final AsyncValue<UserProfile?> profileAsync;

  const _FavoriteBooksCard({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: profileAsync.when(
        loading: () => Text(
          'Carregando...',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
        ),
        error: (_, __) => Text(
          'Não foi possível carregar.',
          style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
        ),
        data: (profile) {
          final favoriteBook = profile?.favoriteBook?.trim();
          if (favoriteBook == null || favoriteBook.isEmpty) {
            return Text(
              'Defina seu livro favorito no perfil.',
              style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
            );
          }
          return Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (_) => Icon(Icons.star_rounded, size: 14, color: ReadLogColors.brass),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  favoriteBook,
                  style: ReadLogType.mono(size: 13, color: ReadLogColors.charcoal),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ClubsCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _ClubsCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _ClubsCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(_clubsProvider);

    return clubsAsync.when(
      loading: () => _card(
        child: const Center(
          child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => _card(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Não foi possível carregar.',
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
        ),
      ),
      data: (clubs) {
        final total = clubs.length;
        final asAdmin = clubs.where((c) => c.isAdmin).length;
        final asOwner = clubs.where((c) => c.isOwner).length;

        return _card(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _MiniStatTile(icon: Icons.groups_outlined, label: 'Participando', value: '$total')),
                  const _VSep(),
                  Expanded(child: _MiniStatTile(icon: Icons.manage_accounts_outlined, label: 'Administrador', value: '$asAdmin')),
                  const _VSep(),
                  Expanded(child: _MiniStatTile(icon: Icons.add_circle_outline, label: 'Criados', value: '$asOwner')),
                ],
              ),
              _divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  label: const Text('Ver Clubes'),
                  style: TextButton.styleFrom(
                    foregroundColor: ReadLogColors.ink,
                    textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _FriendsCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _FriendsCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _FriendsCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_friendsCountProvider);

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 22, color: ReadLogColors.brass),
              const SizedBox(width: 10),
              Text(
                'Amigos',
                style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.65)),
              ),
              const Spacer(),
              countAsync.when(
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Text(
                  '—',
                  style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal),
                ),
                data: (count) => Text(
                  '$count',
                  style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal),
                ),
              ),
            ],
          ),
          _divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: const Text('Ver todos'),
              style: TextButton.styleFrom(
                foregroundColor: ReadLogColors.ink,
                textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CalendarCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _CalendarCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _CalendarCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 22, color: ReadLogColors.brass),
              const SizedBox(width: 10),
              Text(
                'Dias lidos este ano',
                style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.65)),
              ),
              const Spacer(),
              statsAsync.when(
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Text(
                  '—',
                  style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal),
                ),
                data: (stats) {
                  // Conta dias com leitura no heatmap do ano
                  // _profileStatsProvider não carrega heatmap, usamos total de dias aproximado
                  // via fetchPeriodStats: se há minutos, houve leitura
                  final yearStats = stats['yearStats'] as Map<String, dynamic>;
                  final totalMinutes = (yearStats['total_minutes'] as int?) ?? 0;
                  // Sem dados granulares de dias aqui — mostramos total de horas como proxy
                  final hours = totalMinutes ~/ 60;
                  return Text(
                    '${hours}h',
                    style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal),
                  );
                },
              ),
            ],
          ),
          _divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: const Text('Abrir calendário'),
              style: TextButton.styleFrom(
                foregroundColor: ReadLogColors.ink,
                textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _RecentAchievementsCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _RecentAchievementsCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _RecentAchievementsCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);

    return statsAsync.when(
      loading: () => _card(
        child: const Center(
          child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => _card(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Não foi possível carregar.',
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
        ),
      ),
      data: (stats) {
        final achievements = stats['achievements'] as List<Achievement>;
        final unlocked = achievements
            .where((a) => a.isUnlocked)
            .toList()
          ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));

        if (unlocked.isEmpty) {
          return _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    'Nenhuma conquista desbloqueada ainda.',
                    style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
                  ),
                ),
                _divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    label: const Text('Ver todas'),
                    style: TextButton.styleFrom(
                      foregroundColor: ReadLogColors.ink,
                      textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final recent = unlocked.take(3).toList();

        return _card(
          child: Column(
            children: [
              ...recent.asMap().entries.map((e) {
                final isLast = e.key == recent.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(Icons.military_tech_outlined, size: 18, color: ReadLogColors.brass),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value.name,
                              style: ReadLogType.mono(size: 13, color: ReadLogColors.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, thickness: 1, color: ReadLogColors.paperDeep.withValues(alpha: 0.5)),
                  ],
                );
              }),
              _divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  label: const Text('Ver todas'),
                  style: TextButton.styleFrom(
                    foregroundColor: ReadLogColors.ink,
                    textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CollectionCard — dados reais
// ══════════════════════════════════════════════════════════════════════════════

class _CollectionCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _CollectionCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_profileStatsProvider);

    return statsAsync.when(
      loading: () => _card(
        child: const Center(
          child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => _card(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Não foi possível carregar.',
            style: ReadLogType.mono(size: 12, color: ReadLogColors.charcoal.withValues(alpha: 0.45)),
          ),
        ),
      ),
      data: (stats) {
        final books = stats['books'] as List<Book>;
        final total = books.length;
        final wantToRead = books.where((b) => b.status == BookStatus.wantToRead).length;
        final reading = books.where((b) => b.status == BookStatus.reading).length;
        final read = books.where((b) => b.status == BookStatus.read).length;
        final abandoned = books.where((b) => b.status == BookStatus.abandoned).length;

        return _card(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _MiniStatTile(icon: Icons.local_library_outlined, label: 'Total', value: '$total')),
                  const _VSep(),
                  Expanded(child: _MiniStatTile(icon: Icons.bookmark_border_outlined, label: 'Quero ler', value: '$wantToRead')),
                  const _VSep(),
                  Expanded(child: _MiniStatTile(icon: Icons.import_contacts_outlined, label: 'Lendo', value: '$reading')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _MiniStatTile(icon: Icons.check_circle_outline, label: 'Lidos', value: '$read')),
                  const _VSep(),
                  Expanded(child: _MiniStatTile(icon: Icons.cancel_outlined, label: 'Abandonados', value: '$abandoned')),
                  const Expanded(child: SizedBox()),
                ],
              ),
              _divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  label: const Text('Ver biblioteca'),
                  style: TextButton.styleFrom(
                    foregroundColor: ReadLogColors.ink,
                    textStyle: ReadLogType.mono(size: 12, color: ReadLogColors.ink),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares reutilizáveis
// ══════════════════════════════════════════════════════════════════════════════

class _MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, size: 18, color: ReadLogColors.brass),
          const SizedBox(height: 5),
          Text(
            value,
            style: ReadLogType.display(size: 16, color: ReadLogColors.charcoal),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ReadLogType.mono(size: 10, color: ReadLogColors.charcoal.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      color: ReadLogColors.paperDeep.withValues(alpha: 0.5),
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
        radius: 48,
        backgroundColor: ReadLogColors.ink.withValues(alpha: 0.12),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            placeholder: (_, __) => const CircularProgressIndicator(),
            errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials),
          ),
        ),
      );
    }

    return _InitialsAvatar(initials: initials, radius: 48);
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

  const _InitialsAvatar({required this.initials, this.radius = 48});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ReadLogColors.ink,
      child: Text(
        initials,
        style: TextStyle(
          color: ReadLogColors.cream,
          fontSize: radius * 0.58,
          fontWeight: FontWeight.w600,
          fontFamily: 'Fraunces',
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// _QuickLinksGrid — grade 3×N de atalhos para seções sem aba própria
// ══════════════════════════════════════════════════════════════════════════════

class _QuickLink {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.onTap});
}

class _QuickLinksGrid extends StatelessWidget {
  final List<_QuickLink> links;
  const _QuickLinksGrid({required this.links});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: links.length,
      itemBuilder: (_, i) {
        final link = links[i];
        return GestureDetector(
          onTap: link.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: ReadLogColors.cream,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: ReadLogColors.paperDeep.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(link.icon, size: 22, color: ReadLogColors.charcoal.withValues(alpha: 0.7)),
                const SizedBox(height: 6),
                Text(
                  link.label,
                  style: ReadLogType.mono(
                    size: 10,
                    color: ReadLogColors.charcoal.withValues(alpha: 0.75),
                    weight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



// ══════════════════════════════════════════════════════════════════════════════
// _ActivityHeatmapCard — heatmap de atividade de leitura
// ══════════════════════════════════════════════════════════════════════════════

class _ActivityHeatmapCard extends ConsumerWidget {
  const _ActivityHeatmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(_profileHeatmapProvider);

    return heatmapAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: ReadLogColors.brass)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (heatmap) {
        // Converte List<Map> (date, total_minutes) → Map<String,int>
        final data = <String, int>{
          for (final e in heatmap)
            (e['date'] as String? ?? ''): (e['total_minutes'] as num?)?.toInt() ?? 0,
        };
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReadLogReadingHeatmap(data: data),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Configurações',
                style: ReadLogType.display(size: 18, color: cs.onSurface),
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
              Navigator.pop(context);
              context.push('/notifications/settings');
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout_outlined, size: 20, color: AppColors.error),
            title: Text(
              'Sair',
              style: ReadLogType.mono(size: 13, color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 8),
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
      title: Text(label, style: ReadLogType.mono(size: 13, color: cs.onSurface)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: onTap,
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sair', style: ReadLogType.display(size: 16, color: cs.onSurface)),
        content: Text(
          'Tem certeza que deseja sair da sua conta?',
          style: ReadLogType.mono(size: 13, color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: ReadLogType.mono(size: 13, color: cs.onSurface)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await LocalDatabase.instance.clearUserData();
              ref.invalidate(bookRepositoryProvider);
              ref.invalidate(sessionRepositoryProvider);
              ref.invalidate(noteRepositoryProvider);
              ref.invalidate(profileRepositoryProvider);
              ref.invalidate(onboardingCompletedProvider);
              await GoogleSignIn().signOut();
              await Supabase.instance.client.auth.signOut();
            },
            child: Text('Sair', style: ReadLogType.mono(size: 13, color: AppColors.error)),
          ),
        ],
      ),
    );
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
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editar perfil', style: ReadLogType.display(size: 18, color: ReadLogColors.charcoal)),
                const SizedBox(height: 20),
                // ── Avatar picker ──────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: ReadLogColors.ink.withValues(alpha: 0.12),
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
                              color: ReadLogColors.ink,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome de exibição'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  maxLines: 2,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Biografia (opcional)'),
                ),
                const SizedBox(height: 4),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _genreController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Gênero favorito (opcional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _favoriteBookController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Livro favorito (opcional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _authorsController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Autores favoritos (opcional)',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : () => _save(ref),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
