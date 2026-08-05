import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../data/notification_models.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return LumenTexturedBackground(
      child: Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Notificações'),
        leading: const BackButton(),
      ),
      body: prefsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.forestGreen)),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Seção categorias ───────────────────────────────────────────
            _SectionHeader(label: 'Categorias'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: NotificationCategory.values
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final isLast =
                      idx == NotificationCategory.values.length - 1;
                  return _CategoryToggle(
                    category: cat,
                    value: prefs.isEnabled(cat),
                    isLast: isLast,
                    onChanged: (v) => ref
                        .read(notificationPrefsProvider.notifier)
                        .toggleCategory(cat, v),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Seção horários ─────────────────────────────────────────────
            _SectionHeader(label: 'Horário de Leitura'),
            const SizedBox(height: 4),
            Text(
              'Receba lembretes nos horários configurados.',
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...prefs.schedules.map(
              (s) => _ScheduleCard(
                schedule: s,
                onEdit: () => context.push(
                  '/notifications/schedule',
                  extra: s,
                ),
                onDelete: () => ref
                    .read(notificationPrefsProvider.notifier)
                    .removeSchedule(s.id),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/notifications/schedule'),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar horário'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(color: AppColors.forestGreen),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 32),

            // ── Nota sobre inteligência ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.forestGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppColors.forestGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lembretes não são enviados quando você já concluiu '
                      'a meta diária, leu hoje ou abriu o app recentemente.',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}

// ── Toggle de categoria ───────────────────────────────────────────────────────

class _CategoryToggle extends StatelessWidget {
  final NotificationCategory category;
  final bool value;
  final bool isLast;
  final ValueChanged<bool> onChanged;

  const _CategoryToggle({
    required this.category,
    required this.value,
    required this.isLast,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(category.icon, size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                  activeThumbColor: AppColors.forestGreen,
                  activeTrackColor: AppColors.forestGreen.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 56,
            color: AppColors.border,
          ),
      ],
    );
  }
}

// ── Card de horário ───────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final ReadingSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  static const _weekLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final dayLabels = schedule.weekdays
        .toList()
      ..sort();

    final daysStr = dayLabels.isEmpty
        ? 'Nenhum dia'
        : dayLabels.map((d) => _weekLabels[d - 1]).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, color: AppColors.forestGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.timeLabel,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  daysStr,
                  style:
                      AppTextStyles.labelMedium.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textMuted,
            onPressed: onEdit,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.textMuted,
            onPressed: onDelete,
            tooltip: 'Remover',
          ),
        ],
      ),
    );
  }
}

// ── Header de seção ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.titleMedium.copyWith(
        color: AppColors.textPrimary,
        fontSize: 15,
      ),
    );
  }
}
