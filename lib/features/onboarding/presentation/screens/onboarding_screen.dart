import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  // Controladores de campo
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  final _genreController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _goalFocusNode = FocusNode();
  final _genreFocusNode = FocusNode();

  static const _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _goalController.dispose();
    _genreController.dispose();
    _nameFocusNode.dispose();
    _goalFocusNode.dispose();
    _genreFocusNode.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe seu nome.')),
      );
      return;
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

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final goal = int.tryParse(_goalController.text.trim());
      await ref.read(profileRepositoryProvider).upsert({
        'name': _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        'yearly_goal': goal,
        'favorite_genre': _genreController.text.trim().isEmpty
            ? null
            : _genreController.text.trim(),
        'onboarding_completed': true,
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              currentPage: _currentPage,
              totalPages: _totalPages,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _StepPage(
                    icon: Icons.person_outline_rounded,
                    title: 'Como podemos\nte chamar?',
                    subtitle: 'Seu nome será exibido para amigos e clubes.',
                    child: TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Seu nome',
                        hintText: 'Ex.: Maria Silva',
                      ),
                      onFieldSubmitted: (_) => _nextPage(),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.flag_outlined,
                    title: 'Quantos livros\nquer ler este ano?',
                    subtitle:
                        'Defina uma meta para acompanhar seu progresso anual.',
                    child: TextFormField(
                      controller: _goalController,
                      focusNode: _goalFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Meta anual (opcional)',
                        hintText: 'Ex.: 12',
                        suffixText: 'livros',
                      ),
                      onFieldSubmitted: (_) => _nextPage(),
                    ),
                  ),
                  _StepPage(
                    icon: Icons.menu_book_outlined,
                    title: 'Qual é o seu\ngênero favorito?',
                    subtitle:
                        'Usaremos isso para personalizar sua experiência.',
                    child: TextFormField(
                      controller: _genreController,
                      focusNode: _genreFocusNode,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Gênero favorito (opcional)',
                        hintText: 'Ex.: Fantasia, Ficção Científica…',
                      ),
                      onFieldSubmitted: (_) => _nextPage(),
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
              onSkip: _currentPage > 0 ? _nextPage : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header com barra de progresso ────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _OnboardingHeader({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
          const SizedBox(height: 12),
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

// ── Página de passo ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
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
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

// ── Footer com botão de ação ──────────────────────────────────────────────────

class _OnboardingFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool saving;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const _OnboardingFooter({
    required this.currentPage,
    required this.totalPages,
    required this.saving,
    required this.onNext,
    required this.onSkip,
  });

  bool get _isLastPage => currentPage == totalPages - 1;

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
          FilledButton(
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
                : Text(_isLastPage ? 'Começar a ler 🎉' : 'Continuar'),
          ),
          if (onSkip != null && !_isLastPage)
            TextButton(
              onPressed: onSkip,
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
