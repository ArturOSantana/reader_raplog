import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../data/notification_models.dart';

class ReadingScheduleScreen extends ConsumerStatefulWidget {
  /// Quando não-null, estamos editando um horário existente.
  final ReadingSchedule? existing;

  const ReadingScheduleScreen({super.key, this.existing});

  @override
  ConsumerState<ReadingScheduleScreen> createState() =>
      _ReadingScheduleScreenState();
}

class _ReadingScheduleScreenState
    extends ConsumerState<ReadingScheduleScreen> {
  late TimeOfDay _time;
  late Set<int> _weekdays; // 1=segunda … 7=domingo
  bool _saving = false;

  static const _weekLabels = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _time = TimeOfDay(
        hour: widget.existing!.hour,
        minute: widget.existing!.minute,
      );
      _weekdays = Set.from(widget.existing!.weekdays);
    } else {
      _time = const TimeOfDay(hour: 20, minute: 30);
      _weekdays = {1, 2, 3, 4, 5, 6, 7};
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Horário de leitura',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int day) {
    setState(() {
      if (_weekdays.contains(day)) {
        _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
  }

  Future<void> _save() async {
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia.')),
      );
      return;
    }

    setState(() => _saving = true);

    final schedule = ReadingSchedule(
      id: widget.existing?.id ?? const Uuid().v4(),
      hour: _time.hour,
      minute: _time.minute,
      weekdays: Set.from(_weekdays),
    );

    final notifier = ref.read(notificationPrefsProvider.notifier);

    if (widget.existing != null) {
      await notifier.updateSchedule(schedule);
    } else {
      await notifier.addSchedule(schedule);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return LumenTexturedBackground(
      child: Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
            widget.existing != null ? 'Editar horário' : 'Novo horário'),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.forestGreen),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Seletor de hora ──────────────────────────────────────────────
          _SectionLabel(label: 'Horário'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  timeLabel,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Toque para alterar o horário',
              style: AppTextStyles.labelMedium,
            ),
          ),

          const SizedBox(height: 28),

          // ── Dias da semana ───────────────────────────────────────────────
          _SectionLabel(label: 'Repetir'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _weekdays.contains(day);
                return _DayToggle(
                  label: _weekLabels[i],
                  selected: selected,
                  isLast: i == 6,
                  onTap: () => _toggleDay(day),
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // ── Atalhos ──────────────────────────────────────────────────────
          Row(
            children: [
              _ShortcutBtn(
                label: 'Dias úteis',
                onTap: () => setState(
                    () => _weekdays = {1, 2, 3, 4, 5}),
              ),
              const SizedBox(width: 10),
              _ShortcutBtn(
                label: 'Fim de semana',
                onTap: () =>
                    setState(() => _weekdays = {6, 7}),
              ),
              const SizedBox(width: 10),
              _ShortcutBtn(
                label: 'Todos',
                onTap: () =>
                    setState(() => _weekdays = {1, 2, 3, 4, 5, 6, 7}),
              ),
            ],
          ),
        ],
      ),
    )
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  const _DayToggle({
    required this.label,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.forestGreen
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.forestGreen
                          : AppColors.border,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 52, color: AppColors.border),
      ],
    );
  }
}

class _ShortcutBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ShortcutBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forestGreen,
          side: const BorderSide(color: AppColors.forestGreen),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
