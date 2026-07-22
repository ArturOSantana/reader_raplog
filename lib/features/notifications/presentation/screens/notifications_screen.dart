import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/shell/main_shell.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../data/notification_models.dart';
import '../../../inspiration/data/inspiration_quotes.dart';
import '../../../inspiration/presentation/widgets/inspiration_card.dart';

// ── Filtro de categoria ───────────────────────────────────────────────────────

final _inboxFilterProvider =
    StateProvider<NotificationCategory?>((ref) => null);

// ── Tela principal ────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(notificationInboxProvider);
    final filter = ref.watch(_inboxFilterProvider);

    final items = filter == null
        ? inboxState.items
        : inboxState.items.where((i) => i.category == filter).toList();

    // Agrupa por data
    final groups = _groupByDate(items);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
          tooltip: 'Abrir menu',
        ),
        title: const Text('Notificações'),
        actions: [
          if (inboxState.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationInboxProvider.notifier).markAllRead(),
              child: Text(
                'Marcar tudo',
                style: TextStyle(
                  color: AppColors.forestGreen,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Configurações',
            onPressed: () => context.push('/notifications/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros de categoria
          _CategoryFilterBar(selected: filter),
          Expanded(
            child: inboxState.loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.forestGreen),
                  )
                : inboxState.error != null
                    ? _ErrorView(
                        onRetry: () => ref
                            .read(notificationInboxProvider.notifier)
                            .load(),
                      )
                    : items.isEmpty
                        ? _EmptyView(hasFilter: filter != null)
                        : RefreshIndicator(
                            color: AppColors.forestGreen,
                            onRefresh: () => ref
                                .read(notificationInboxProvider.notifier)
                                .load(),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: groups.length,
                              itemBuilder: (context, i) {
                                final entry = groups.entries.elementAt(i);
                                return _DateGroup(
                                  label: entry.key,
                                  items: entry.value,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  static Map<String, List<NotificationItem>> _groupByDate(
      List<NotificationItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final result = <String, List<NotificationItem>>{};
    for (final item in items) {
      final d = DateTime(
          item.createdAt.year, item.createdAt.month, item.createdAt.day);
      String label;
      if (d == today) {
        label = 'Hoje';
      } else if (d == yesterday) {
        label = 'Ontem';
      } else {
        label = DateFormat('d MMM', 'pt_BR').format(item.createdAt);
      }
      result.putIfAbsent(label, () => []).add(item);
    }
    return result;
  }
}

// ── Barra de filtros ──────────────────────────────────────────────────────────

class _CategoryFilterBar extends ConsumerWidget {
  final NotificationCategory? selected;

  const _CategoryFilterBar({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'Todas',
            emoji: '🔔',
            selected: selected == null,
            onTap: () =>
                ref.read(_inboxFilterProvider.notifier).state = null,
          ),
          ...NotificationCategory.values.map((cat) => _FilterChip(
                label: cat.label,
                emoji: cat.emoji,
                selected: selected == cat,
                onTap: () =>
                    ref.read(_inboxFilterProvider.notifier).state = cat,
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forestGreen
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.forestGreen : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grupo por data ────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final String label;
  final List<NotificationItem> items;

  const _DateGroup({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items.map((item) => _NotifTile(item: item)),
      ],
    );
  }
}

// ── Tile de notificação ───────────────────────────────────────────────────────

class _NotifTile extends ConsumerWidget {
  final NotificationItem item;

  const _NotifTile({required this.item});

  /// Retorna o contexto de inspiração compatível com a categoria da notificação,
  /// ou null quando não há frase específica para essa categoria.
  static InspirationContext? _inspirationContextFor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.streak:
        return InspirationContext.streakAtRisk;
      case NotificationCategory.reading:
        return InspirationContext.readingTime;
      case NotificationCategory.achievements:
        return InspirationContext.achievementUnlocked;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (!item.isRead) {
          ref.read(notificationInboxProvider.notifier).markRead(item.id);
        }
        final ctx = _inspirationContextFor(item.category);
        if (ctx != null) {
          final service = ref.read(dailyInspirationServiceProvider);
          final quote = await service.pick(ctx);
          if (!context.mounted) return;
          InspirationBottomSheet.show(
            context,
            quote: quote,
            title: '${item.category.emoji} ${item.title.toUpperCase()}',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.transparent : AppColors.forestGreen.withValues(alpha: 0.04),
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji da categoria
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  item.category.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(item.createdAt),
                    style: AppTextStyles.labelMedium,
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return DateFormat('d MMM', 'pt_BR').format(dt);
  }
}

// ── Estados vazios / erro ─────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool hasFilter;

  const _EmptyView({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Nenhuma notificação nessa categoria'
                  : 'Nenhuma notificação ainda',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Erro ao carregar notificações', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
