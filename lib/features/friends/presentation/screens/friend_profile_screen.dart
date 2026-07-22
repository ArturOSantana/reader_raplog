import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/friend.dart';
import '../../../../shared/providers/providers.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _pubProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).fetchPublicProfile(userId);
});

final _pubStatsProvider =
    FutureProvider.family<FriendPublicStats, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).fetchPublicStats(userId);
});

final _currentBookProvider =
    FutureProvider.family<FriendCurrentBook?, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).fetchCurrentBook(userId);
});

final _calendarProvider =
    FutureProvider.family<List<DateTime>, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).fetchPublicCalendar(userId);
});

final _relProvider =
    FutureProvider.family<String, String>((ref, userId) {
  return ref.read(friendsRepositoryProvider).relationshipStatus(userId);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class FriendProfileScreen extends ConsumerWidget {
  final String userId;

  const FriendProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_pubProfileProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.offWhite,
        foregroundColor: AppColors.textPrimary,
        title: profileAsync.maybeWhen(
          data: (p) => Text(p?.name ?? 'Perfil', style: AppTextStyles.titleMedium),
          orElse: () => const Text('Perfil'),
        ),
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Não foi possível carregar o perfil.')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          return _ProfileBody(
            userId: userId,
            profile: profile,
            onRefresh: () {
              ref.invalidate(_pubProfileProvider(userId));
              ref.invalidate(_pubStatsProvider(userId));
              ref.invalidate(_currentBookProvider(userId));
              ref.invalidate(_relProvider(userId));
            },
          );
        },
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final String userId;
  final PublicProfile profile;
  final VoidCallback onRefresh;

  const _ProfileBody({
    required this.userId,
    required this.profile,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_pubStatsProvider(userId));
    final currentBookAsync = ref.watch(_currentBookProvider(userId));
    final calendarAsync = ref.watch(_calendarProvider(userId));
    final relAsync = ref.watch(_relProvider(userId));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header ──────────────────────────────────────────────────
        _ProfileHeader(profile: profile, relAsync: relAsync, onAction: onRefresh),

        const _Divider(),

        // ── Livro atual ─────────────────────────────────────────────
        if (profile.privacy.currentBook)
          currentBookAsync.when(
            loading: () => const _SectionSkeleton(label: 'Lendo agora'),
            error: (_, __) => const SizedBox.shrink(),
            data: (book) => _CurrentBookSection(book: book),
          )
        else
          _PrivateSection(
            icon: Icons.menu_book_outlined,
            label: 'Livro atual',
          ),

        const _Divider(),

        // ── Resumo do leitor ─────────────────────────────────────────
        statsAsync.when(
          loading: () => const _SectionSkeleton(label: 'Carregando estatísticas…'),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => _ReaderSummary(stats: stats),
        ),

        const _Divider(),

        // ── Preferências ─────────────────────────────────────────────
        _PreferencesSection(profile: profile),

        const _Divider(),

        // ── Estatísticas ─────────────────────────────────────────────
        statsAsync.when(
          loading: () => const _SectionSkeleton(label: 'Estatísticas'),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => _StatsSection(stats: stats),
        ),

        const _Divider(),

        // ── Biblioteca ───────────────────────────────────────────────
        statsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => _LibrarySection(stats: stats),
        ),

        const _Divider(),

        // ── Meta anual ───────────────────────────────────────────────
        statsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => stats.yearlyGoal != null
              ? _YearlyGoalSection(stats: stats)
              : const SizedBox.shrink(),
        ),

        const _Divider(),

        // ── Calendário ───────────────────────────────────────────────
        if (profile.privacy.calendar)
          calendarAsync.when(
            loading: () => const _SectionSkeleton(label: 'Calendário'),
            error: (_, __) => const SizedBox.shrink(),
            data: (dates) => _CalendarSection(dates: dates),
          )
        else
          _PrivateSection(
            icon: Icons.calendar_month_outlined,
            label: 'Calendário de leitura',
          ),

        const _Divider(),

        // ── Compatibilidade ──────────────────────────────────────────
        if (profile.privacy.compatibility)
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _CompatibilitySection(profile: profile, stats: stats),
          ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final PublicProfile profile;
  final AsyncValue<String> relAsync;
  final VoidCallback onAction;

  const _ProfileHeader({
    required this.profile,
    required this.relAsync,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          // Avatar
          _Avatar(url: profile.avatarUrl, name: profile.name ?? '?'),
          const SizedBox(height: 16),

          // Nome
          if (profile.name != null && profile.name!.isNotEmpty)
            Text(
              profile.name!,
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),

          // Username
          if (profile.username != null && profile.username!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '@${profile.username}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Localização e membro desde
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile.location != null && profile.location!.isNotEmpty) ...[
                Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(profile.location!, style: AppTextStyles.labelMedium),
                const SizedBox(width: 16),
              ],
              if (profile.memberSince != null) ...[
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Membro desde ${_monthYear(profile.memberSince!)}',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ],
          ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '"${profile.bio}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),

          // Botões de ação
          relAsync.when(
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox.shrink(),
            data: (rel) => _ActionRow(
              relationship: rel,
              profile: profile,
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }

  static String _monthYear(DateTime dt) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${months[dt.month - 1]}/${dt.year}';
  }
}

// ── Botões de ação ────────────────────────────────────────────────────────────

class _ActionRow extends ConsumerWidget {
  final String relationship;
  final PublicProfile profile;
  final VoidCallback onAction;

  const _ActionRow({
    required this.relationship,
    required this.profile,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFriend = relationship == 'friend';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isFriend)
          _SmallButton(
            icon: Icons.favorite_outline,
            label: 'Amigo',
            onTap: () => _confirmRemove(context, ref),
            filled: true,
          )
        else if (relationship == 'pending_sent')
          _SmallButton(
            icon: Icons.hourglass_top_outlined,
            label: 'Enviado',
            onTap: null,
          )
        else if (relationship == 'pending_received')
          _SmallButton(
            icon: Icons.check,
            label: 'Aceitar',
            onTap: () => _accept(context, ref),
            filled: true,
          )
        else
          _SmallButton(
            icon: Icons.person_add_outlined,
            label: 'Adicionar',
            onTap: () => _sendRequest(context, ref),
            filled: true,
          ),
        const SizedBox(width: 12),
        _SmallButton(
          icon: Icons.chat_bubble_outline,
          label: 'Mensagem',
          onTap: () {},
        ),
        const SizedBox(width: 12),
        _SmallButton(
          icon: Icons.library_books_outlined,
          label: 'Convidar',
          onTap: () {},
        ),
      ],
    );
  }

  Future<void> _sendRequest(BuildContext context, WidgetRef ref) async {
    await ref.read(friendsRepositoryProvider).sendRequest(profile.id);
    onAction();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação enviada!')),
      );
    }
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final req =
        await ref.read(friendsRepositoryProvider).listPendingReceived();
    final match = req.where((r) => r.senderId == profile.id).firstOrNull;
    if (match != null) {
      await ref.read(friendsRepositoryProvider).acceptRequest(match.id);
      onAction();
    }
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover amigo'),
        content: Text(
            'Deseja remover ${profile.name ?? "este usuário"} da sua lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(friendsRepositoryProvider)
                  .removeFriend(profile.id);
              onAction();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: filled
                  ? AppColors.forestGreen
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: filled
                  ? null
                  : Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: filled ? Colors.white : AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

// ── Livro Atual ───────────────────────────────────────────────────────────────

class _CurrentBookSection extends StatelessWidget {
  final FriendCurrentBook? book;

  const _CurrentBookSection({required this.book});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.menu_book_outlined,
      title: 'Lendo agora',
      child: book == null
          ? Text('Nenhum livro em andamento.',
              style: AppTextStyles.bodyMedium)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book!.title,
                  style: AppTextStyles.titleMedium,
                ),
                if (book!.author != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      book!.author!,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 12),
                // Barra de progresso
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book!.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${book!.progressPercent}%',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    Text(
                      'Página ${book!.currentPage} de ${book!.totalPages}',
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Começou há ${book!.daysReading} ${book!.daysReading == 1 ? "dia" : "dias"}',
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
    );
  }
}

// ── Resumo do Leitor ──────────────────────────────────────────────────────────

class _ReaderSummary extends StatelessWidget {
  final FriendPublicStats stats;

  const _ReaderSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.bar_chart_rounded,
      title: 'Resumo do leitor',
      child: Column(
        children: [
          _StatRow(
            emoji: '🔥',
            label: 'Ofensiva',
            value: '${stats.streak} ${stats.streak == 1 ? "dia" : "dias"}',
          ),
          _StatRow(
            emoji: '📚',
            label: 'Livros concluídos',
            value: '${stats.booksCompleted}',
          ),
          _StatRow(
            emoji: '📄',
            label: 'Páginas lidas',
            value: _formatNumber(stats.pagesRead),
          ),
          _StatRow(
            emoji: '⏱',
            label: 'Tempo de leitura',
            value: '${(stats.readingMinutes / 60).floor()} horas',
          ),
          _StatRow(
            emoji: '🏅',
            label: 'Conquistas',
            value: '${stats.achievements}',
            last: true,
          ),
        ],
      ),
    );
  }
}

// ── Preferências ──────────────────────────────────────────────────────────────

class _PreferencesSection extends StatelessWidget {
  final PublicProfile profile;

  const _PreferencesSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final genreList = (profile.favoriteGenre ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final authorList = (profile.favoriteAuthors ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final favoriteBook = profile.favoriteBook;
    final format = profile.preferredFormat;

    if (genreList.isEmpty &&
        authorList.isEmpty &&
        favoriteBook == null &&
        format == null) {
      return const SizedBox.shrink();
    }

    return _Section(
      icon: Icons.tune_outlined,
      title: 'Preferências',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (format != null) ...[
            Text('Formato preferido', style: AppTextStyles.labelMedium),
            const SizedBox(height: 4),
            _Tag(label: _formatLabel(format)),
            const SizedBox(height: 16),
          ],
          if (genreList.isNotEmpty) ...[
            Text('Gêneros favoritos', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: genreList.map((g) => _Tag(label: g)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (authorList.isNotEmpty) ...[
            Text('Autores favoritos', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            ...authorList.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: AppColors.forestGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(a, style: AppTextStyles.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (favoriteBook != null && favoriteBook.isNotEmpty) ...[
            Text('Livro favorito', style: AppTextStyles.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(
                    5,
                    (i) => Icon(Icons.star_rounded,
                        size: 14, color: AppColors.warmGold)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(favoriteBook,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatLabel(String fmt) => switch (fmt) {
        'physical' => 'Livro Físico',
        'ebook' => 'Ebook',
        'both' => 'Ambos',
        _ => fmt,
      };
}

// ── Estatísticas detalhadas ───────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final FriendPublicStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final bestH = stats.bestSessionMinutes ~/ 60;
    final bestM = stats.bestSessionMinutes % 60;
    return _Section(
      icon: Icons.insights_outlined,
      title: 'Estatísticas',
      child: Column(
        children: [
          _StatRow(label: 'Maior ofensiva', value: '${stats.bestStreak} dias'),
          _StatRow(
            label: 'Maior sessão',
            value: bestH > 0
                ? '${bestH}h${bestM.toString().padLeft(2, "0")}'
                : '${bestM}min',
          ),
          _StatRow(label: 'Tempo médio', value: '${stats.avgSessionMinutes} minutos'),
          _StatRow(
              label: 'Páginas por sessão',
              value: '${stats.avgPagesPerSession}'),
          _StatRow(
            label: 'Livros este ano',
            value: '${stats.booksThisYear}',
            last: true,
          ),
        ],
      ),
    );
  }
}

// ── Biblioteca ────────────────────────────────────────────────────────────────

class _LibrarySection extends StatelessWidget {
  final FriendPublicStats stats;

  const _LibrarySection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.library_books_outlined,
      title: 'Biblioteca',
      child: Column(
        children: [
          _StatRow(label: 'Lendo', value: '${stats.libraryReading}'),
          _StatRow(label: 'Quero Ler', value: '${stats.libraryWishlist}'),
          _StatRow(label: 'Lidos', value: '${stats.libraryRead}'),
          _StatRow(
            label: 'Abandonados',
            value: '${stats.libraryAbandoned}',
            last: true,
          ),
        ],
      ),
    );
  }
}

// ── Meta Anual ────────────────────────────────────────────────────────────────

class _YearlyGoalSection extends StatelessWidget {
  final FriendPublicStats stats;

  const _YearlyGoalSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final goal = stats.yearlyGoal!;
    final progress = goal > 0
        ? (stats.yearlyProgress / goal).clamp(0.0, 1.0)
        : 0.0;
    return _Section(
      icon: Icons.flag_outlined,
      title: 'Meta anual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.border,
              color: AppColors.warmGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.yearlyProgress} / $goal livros',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendário ────────────────────────────────────────────────────────────────

class _CalendarSection extends StatefulWidget {
  final List<DateTime> dates;

  const _CalendarSection({required this.dates});

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final readDays = widget.dates
        .map((d) => '${d.year}-${d.month}-${d.day}')
        .toSet();

    final daysInMonth =
        DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;

    const monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    return _Section(
      icon: Icons.calendar_month_outlined,
      title: 'Calendário de leitura',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navegação de mês
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                }),
                color: AppColors.forestGreen,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Text(
                  '${monthNames[_month.month - 1]} ${_month.year}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                }),
                color: AppColors.forestGreen,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Labels de dia da semana
          Row(
            children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: AppTextStyles.labelMedium),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < firstWeekday) return const SizedBox.shrink();
              final day = i - firstWeekday + 1;
              final key = '${_month.year}-${_month.month}-$day';
              final hasReading = readDays.contains(key);
              return Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasReading
                        ? AppColors.forestGreen
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.forestGreen,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Com leitura', style: AppTextStyles.labelMedium),
              const SizedBox(width: 16),
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Sem leitura', style: AppTextStyles.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Compatibilidade ───────────────────────────────────────────────────────────

class _CompatibilitySection extends StatelessWidget {
  final PublicProfile profile;
  final FriendPublicStats stats;

  const _CompatibilitySection({
    required this.profile,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // Cálculo simples de compatibilidade baseado em campos preenchidos em comum
    int score = 0;
    if (profile.favoriteGenre != null) score += 30;
    if (profile.favoriteAuthors != null) score += 40;
    if (profile.favoriteBook != null) score += 30;
    score = score.clamp(0, 100);

    return _Section(
      icon: Icons.favorite_outline,
      title: 'Compatibilidade literária',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$score%',
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 12,
                    backgroundColor: AppColors.border,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Baseado em gêneros, autores e livros favoritos.',
            style: AppTextStyles.labelMedium,
          ),
        ],
      ),
    );
  }
}

// ── Privado ───────────────────────────────────────────────────────────────────

class _PrivateSection extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PrivateSection({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodyMedium),
          const SizedBox(width: 8),
          const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text('Privado', style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.forestGreen),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── StatRow ───────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String? emoji;
  final String label;
  final String value;
  final bool last;

  const _StatRow({
    this.emoji,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label, style: AppTextStyles.bodyMedium),
              ),
              Text(
                value,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textSecondary,
      )),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 24,
      endIndent: 24,
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SectionSkeleton extends StatelessWidget {
  final String label;

  const _SectionSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 12),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(url!),
        backgroundColor: AppColors.forestGreen.withValues(alpha: 0.12),
      );
    }
    final initials = _initials(name);
    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w600,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatNumber(int n) {
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  }
  return '$n';
}
