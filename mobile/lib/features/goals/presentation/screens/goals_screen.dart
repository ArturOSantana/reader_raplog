import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../theme/lumen_theme.dart';
import '../../../../shared/models/goal.dart';
import '../../../../shared/providers/providers.dart';

final _goalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).fetchAll();
});

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(_goalsProvider);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Missões')),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => _GoalsList(goals: list),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(context, ref),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddGoalSheet(onSaved: () {
        ref.invalidate(_goalsProvider);
      }),
    );
  }
}

class _GoalsList extends ConsumerWidget {
  final List<Goal> goals;

  const _GoalsList({required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_outlined, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Nenhuma missão definida',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Toque no + para criar uma missão de leitura.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _GoalTile(
        goal: goals[i],
        onDelete: () async {
          await ref.read(goalRepositoryProvider).delete(goals[i].id);
          ref.invalidate(_goalsProvider);
        },
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback onDelete;

  const _GoalTile({required this.goal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LumenColors.readSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.forestGreen, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.type.label, style: AppTextStyles.titleMedium),
                Text(
                  '${goal.targetValue} ${goal.type.unit}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddGoalSheet({required this.onSaved});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  GoalType _selectedType = GoalType.dailyMinutes;
  final _valueController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save(WidgetRef ref) async {
    final value = int.tryParse(_valueController.text);
    if (value == null || value <= 0) return;
    setState(() => _loading = true);
    await ref.read(goalRepositoryProvider).upsert(
          type: _selectedType,
          targetValue: value,
        );
    setState(() => _loading = false);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova missão', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            Text('Tipo de missão', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GoalType.values.map((t) {
                final selected = _selectedType == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = t),
                  selectedColor: AppColors.forestGreen,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantidade (${_selectedType.unit})',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _save(ref),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Salvar missão'),
            ),
          ],
        ),
      ),
    );
  }
}
