import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/lumen_theme.dart';
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

    final groups = _groupByDate(items);

    return Scaffold(
      backgroundColor: ReadLogColors.paper,
      appBar: AppBar(
        backgroundColor: ReadLogColors.paper,
        foregroundColor: ReadLogColors.charcoal,
        automaticallyImplyLeading: false,
        title: Text(
          'Notificações',
          style: ReadLogType.display(size: 19, color: ReadLogColors.charcoal),
        ),
        actions: [
          if (inboxState.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationInboxProvider.notifier).markAllRead(),
              child: Text(
                'Marcar tudo',
                style: ReadLogType.mono(
                  size: 12,
                  color: ReadLogColors.brass,
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
          _CategoryFilterBar(selected: filter),
          Expanded(
            child: inboxState.loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: ReadLogColors.brass),
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
                            color: ReadLogColors.brass,
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
    return Container(
      color: ReadLogColors.paperAlt,
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            _FilterChip(
              label: 'Todas',
              icon: Icons.notifications_outlined,
              selected: selected == null,
              onTap: () =>
                  ref.read(_inboxFilterProvider.notifier).state = null,
            ),
            ...NotificationCategory.values.map((cat) => _FilterChip(
                  label: cat.label,
                  icon: cat.icon,
                  selected: selected == cat,
                  onTap: () =>
                      ref.read(_inboxFilterProvider.notifier).state = cat,
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? ReadLogColors.charcoal : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: selected
                ? ReadLogColors.charcoal
                : ReadLogColors.charcoal.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: ReadLogType.mono(
                size: 10,
                color: selected
                    ? ReadLogColors.paper
                    : ReadLogColors.charcoal.withValues(alpha: 0.65),
              ).copyWith(letterSpacing: 0.5),
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
            label.toUpperCase(),
            style: ReadLogType.mono(
              size: 9.5,
              color: ReadLogColors.charcoal.withValues(alpha: 0.5),
            ).copyWith(letterSpacing: 0.8),
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

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return DateFormat('d MMM', 'pt_BR').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ReadLogNotificationTile(
        icon: item.category.icon,
        title: item.title,
        subtitle: item.body,
        time: _timeAgo(item.createdAt),
        unread: !item.isRead,
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
              title: item.title.toUpperCase(),
            );
          }
        },
      ),
    );
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
            Icon(
              Icons.notifications_none_outlined,
              size: 56,
              color: ReadLogColors.charcoal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Nenhuma notificação nessa categoria'
                  : 'Nenhuma notificação ainda',
              style: ReadLogType.mono(
                size: 13,
                color: ReadLogColors.charcoal.withValues(alpha: 0.5),
              ),
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
          Text(
            'Erro ao carregar notificações',
            style: ReadLogType.mono(
              size: 13,
              color: ReadLogColors.charcoal.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
