import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/models/goal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dados auxiliares
// ─────────────────────────────────────────────────────────────────────────────

const _genres = [
  'Romance',
  'Ficção Científica',
  'Fantasy',
  'Terror',
  'Suspense',
  'Biografia',
  'História',
  'Autoajuda',
  'Filosofia',
  'Poesia',
  'Crônicas',
  'Infantil',
  'Policial',
  'Clássicos',
  'Negócios',
];

/// Perfis de leitor: label, ícone, livros/ano sugeridos
const _readerProfiles = [
  _ReaderProfile('Iniciante', Icons.spa_outlined, 'Leio pouco, quero criar o hábito', 6),
  _ReaderProfile('Casual', Icons.book_outlined, 'Leio de vez em quando, alguns por ano', 12),
  _ReaderProfile('Regular', Icons.auto_stories_outlined, 'Leio todo mês, pelo menos um livro', 18),
  _ReaderProfile('Ávido', Icons.local_fire_department_outlined, 'Leio bastante, quase toda semana', 30),
  _ReaderProfile('Devorador', Icons.bolt_outlined, 'Leio todo dia, vários livros por mês', 52),
];

class _ReaderProfile {
  final String label;
  final IconData icon;
  final String description;
  final int suggestedBooks;
  const _ReaderProfile(this.label, this.icon, this.description, this.suggestedBooks);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  // Passo 1: nome
  final _nameController = TextEditingController();

  // Passo 2: perfil de leitor
  int? _selectedProfileIndex;

  // Passo 3: meta de livros (editável após o perfil sugerir)
  final _yearlyGoalController = TextEditingController();

  // Passo 4: ritmo diário
  GoalType? _dailyGoalType; // dailyPages ou dailyMinutes
  final _dailyGoalController = TextEditingController();

  // Passo 5: gêneros favoritos
  final Set<String> _selectedGenres = {};
  final _customGenreController = TextEditingController();

  // Passo 6: livro e autor favorito
  final _favoriteBookController = TextEditingController();
  final _favoriteAuthorController = TextEditingController();

  // Passo 0 é a tela de boas-vindas (sem dados), então 7 páginas no total:
  // 0-welcome, 1-name, 2-profile, 3-yearly-goal, 4-daily-goal, 5-genres, 6-favorites
  static const _totalPages = 7;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _yearlyGoalController.dispose();
    _dailyGoalController.dispose();
    _customGenreController.dispose();
    _favoriteBookController.dispose();
    _favoriteAuthorController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 1:
        return _nameController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (!_canProceed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe seu nome.')),
      );
      return;
    }

    // Ao sair da tela de perfil, pré-preenche a meta de livros
    if (_currentPage == 2 && _selectedProfileIndex != null) {
      final suggested = _readerProfiles[_selectedProfileIndex!].suggestedBooks;
      if (_yearlyGoalController.text.trim().isEmpty) {
        _yearlyGoalController.text = suggested.toString();
      }
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final yearlyGoal = int.tryParse(_yearlyGoalController.text.trim());

      // Salva perfil
      final favoriteAuthors = _favoriteAuthorController.text.trim();
      final favoriteBook = _favoriteBookController.text.trim();
      final genres = _selectedGenres.toList();
      if (_customGenreController.text.trim().isNotEmpty) {
        genres.add(_customGenreController.text.trim());
      }

      await ref.read(profileRepositoryProvider).upsert({
        'name': _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        'yearly_goal': yearlyGoal,
        'favorite_genre': genres.isEmpty ? null : genres.join(', '),
        'favorite_authors': favoriteAuthors.isEmpty ? null : favoriteAuthors,
        'favorite_book': favoriteBook.isEmpty ? null : favoriteBook,
        'onboarding_completed': true,
      });

      // Salva meta anual de livros
      if (yearlyGoal != null && yearlyGoal > 0) {
        await ref.read(goalRepositoryProvider).upsert(
              type: GoalType.yearlyBooks,
              targetValue: yearlyGoal,
            );
      }

      // Salva meta diária
      final dailyTarget = int.tryParse(_dailyGoalController.text.trim());
      if (_dailyGoalType != null && dailyTarget != null && dailyTarget > 0) {
        await ref.read(goalRepositoryProvider).upsert(
              type: _dailyGoalType!,
              targetValue: dailyTarget,
            );
      }

      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar. Tente novamente.')),
        );
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFirst = _currentPage == 0;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              currentPage: _currentPage,
              totalPages: _totalPages,
              showBack: !isFirst,
              onBack: _prevPage,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(),
                  _StepPage(
                    icon: Icons.person_outline_rounded,
                    title: 'Como podemos\nte chamar?',
                    subtitle: 'Seu nome será exibido para amigos e clubes de leitura.',
                    child: TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Seu nome'),
                      onFieldSubmitted: (_) => _nextPage(),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.person_search_outlined,
                    title: 'Qual é o seu\nperfil de leitor?',
                    subtitle: 'Isso vai nos ajudar a sugerir metas ideais para você.',
                    child: _ReaderProfileSelector(
                      selectedIndex: _selectedProfileIndex,
                      onSelected: (i) => setState(() => _selectedProfileIndex = i),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.flag_outlined,
                    title: 'Meta anual\nde livros',
                    subtitle: _selectedProfileIndex != null
                        ? 'Sugerimos ${_readerProfiles[_selectedProfileIndex!].suggestedBooks} livros com base no seu perfil. Ajuste como quiser!'
                        : 'Defina quantos livros quer terminar este ano.',
                    child: TextFormField(
                      controller: _yearlyGoalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Meta anual (opcional)',
                        suffixText: 'livros',
                      ),
                      onFieldSubmitted: (_) => _nextPage(),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.timer_outlined,
                    title: 'Meta diária\nde leitura',
                    subtitle: 'Defina um ritmo diário — pode ser por páginas ou minutos.',
                    child: _DailyGoalStep(
                      selectedType: _dailyGoalType,
                      controller: _dailyGoalController,
                      onTypeChanged: (t) => setState(() => _dailyGoalType = t),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.menu_book_outlined,
                    title: 'Quais gêneros\nvocê mais curte?',
                    subtitle: 'Selecione quantos quiser — usaremos para personalizar sua experiência.',
                    child: _GenreSelector(
                      selected: _selectedGenres,
                      customController: _customGenreController,
                      onToggle: (g) => setState(() {
                        if (_selectedGenres.contains(g)) {
                          _selectedGenres.remove(g);
                        } else {
                          _selectedGenres.add(g);
                        }
                      }),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Livro e autor\nfavoritos',
                    subtitle: 'Opcional, mas ajuda a conectar você com leitores parecidos.',
                    child: _FavoritesStep(
                      bookController: _favoriteBookController,
                      authorController: _favoriteAuthorController,
                      onSubmit: _nextPage,
                    ),
                  ),
                ],
              ),
            ),
            _OnboardingFooter(
              currentPage: _currentPage,
              totalPages: _totalPages,
              saving: _saving,
              onNext: _nextPage,
              canSkip: _currentPage > 1, // nome não pode pular
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela de boas-vindas
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: AppColors.forestGreen, size: 32),
          ),
          const SizedBox(height: 24),
          const Text('Bem-vindo ao\nReadLog!',
              style: AppTextStyles.displayMedium),
          const SizedBox(height: 12),
          Text(
            'Seu diário de leitura inteligente.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ..._features.map((f) => _FeatureRow(icon: f.$1, text: f.$2)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.forestGreen.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.forestGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O setup leva menos de 2 minutos e vai personalizar toda a sua experiência.',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.forestGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (Icons.library_books_outlined, 'Registre todos os livros que leu, está lendo ou quer ler'),
    (Icons.timer_outlined, 'Registre sessões de leitura e acompanhe seu tempo'),
    (Icons.flag_outlined, 'Defina metas anuais, mensais e diárias de leitura'),
    (Icons.emoji_events_outlined, 'Desbloqueie conquistas conforme você avança'),
    (Icons.people_outline_rounded, 'Conecte-se com amigos e participe de clubes de leitura'),
    (Icons.format_quote_rounded, 'Salve citações e anotações dos seus livros favoritos'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.forestGreen, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: AppTextStyles.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seletor de perfil de leitor
// ─────────────────────────────────────────────────────────────────────────────

class _ReaderProfileSelector extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _ReaderProfileSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_readerProfiles.length, (i) {
        final p = _readerProfiles[i];
        final selected = selectedIndex == i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelected(i),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.forestGreen.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.forestGreen
                      : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(p.icon,
                      color: selected
                          ? AppColors.forestGreen
                          : AppColors.textSecondary,
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.label,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: selected
                                  ? AppColors.forestGreen
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 2),
                        Text(p.description,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.forestGreen, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta diária — tipo + valor
// ─────────────────────────────────────────────────────────────────────────────

class _DailyGoalStep extends StatelessWidget {
  final GoalType? selectedType;
  final TextEditingController controller;
  final ValueChanged<GoalType?> onTypeChanged;

  const _DailyGoalStep({
    required this.selectedType,
    required this.controller,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de tipo
        Row(
          children: [
            _TypeChip(
              label: 'Páginas / dia',
              icon: Icons.description_outlined,
              selected: selectedType == GoalType.dailyPages,
              onTap: () => onTypeChanged(
                selectedType == GoalType.dailyPages ? null : GoalType.dailyPages,
              ),
            ),
            const SizedBox(width: 10),
            _TypeChip(
              label: 'Minutos / dia',
              icon: Icons.schedule_outlined,
              selected: selectedType == GoalType.dailyMinutes,
              onTap: () => onTypeChanged(
                selectedType == GoalType.dailyMinutes ? null : GoalType.dailyMinutes,
              ),
            ),
          ],
        ),
        if (selectedType != null) ...[
          const SizedBox(height: 20),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              labelText: selectedType == GoalType.dailyPages
                  ? 'Páginas por dia'
                  : 'Minutos por dia',
              suffixText: selectedType == GoalType.dailyPages ? 'pág.' : 'min',
            ),
          ),
        ],
        if (selectedType == null) ...[
          const SizedBox(height: 16),
          Text(
            'Você pode pular e definir depois nas configurações.',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forestGreen.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.forestGreen : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected
                    ? AppColors.forestGreen
                    : AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.forestGreen
                    : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seletor de gêneros
// ─────────────────────────────────────────────────────────────────────────────

class _GenreSelector extends StatelessWidget {
  final Set<String> selected;
  final TextEditingController customController;
  final ValueChanged<String> onToggle;

  const _GenreSelector({
    required this.selected,
    required this.customController,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _genres.map((g) {
            final isSelected = selected.contains(g);
            return FilterChip(
              label: Text(g),
              selected: isSelected,
              onSelected: (_) => onToggle(g),
              selectedColor: AppColors.forestGreen.withValues(alpha: 0.12),
              checkmarkColor: AppColors.forestGreen,
              side: BorderSide(
                color: isSelected ? AppColors.forestGreen : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? AppColors.forestGreen : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              backgroundColor: AppColors.surface,
              showCheckmark: true,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: customController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Outro gênero (opcional)',
            prefixIcon: Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Favoritos (livro + autor)
// ─────────────────────────────────────────────────────────────────────────────

class _FavoritesStep extends StatelessWidget {
  final TextEditingController bookController;
  final TextEditingController authorController;
  final VoidCallback onSubmit;

  const _FavoritesStep({
    required this.bookController,
    required this.authorController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: bookController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Livro favorito (opcional)',
            prefixIcon: Icon(Icons.book_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: authorController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Autor favorito (opcional)',
            prefixIcon: Icon(Icons.person_outlined),
          ),
          onFieldSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header com barra de progresso + botão voltar
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool showBack;
  final VoidCallback onBack;

  const _OnboardingHeader({
    required this.currentPage,
    required this.totalPages,
    required this.showBack,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondary,
                )
              else
                const Text(
                  'ReadLog',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestGreen,
                  ),
                ),
              const Spacer(),
              Text(
                '${currentPage + 1} de $totalPages',
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentPage + 1) / totalPages,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página de passo genérica
// ─────────────────────────────────────────────────────────────────────────────

class _StepPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.forestGreen, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool saving;
  final VoidCallback onNext;
  final bool canSkip;

  const _OnboardingFooter({
    required this.currentPage,
    required this.totalPages,
    required this.saving,
    required this.onNext,
    required this.canSkip,
  });

  bool get _isLastPage => currentPage == totalPages - 1;
  bool get _isWelcome => currentPage == 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onNext,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_isWelcome
                      ? 'Começar configuração'
                      : _isLastPage
                          ? 'Começar a ler 🎉'
                          : 'Continuar'),
            ),
          ),
          if (canSkip && !_isLastPage)
            TextButton(
              onPressed: onNext,
              child: Text(
                'Pular por agora',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
