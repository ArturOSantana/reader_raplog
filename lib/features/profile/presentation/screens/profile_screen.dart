import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/shell/main_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/providers/providers.dart';

final _profileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).fetch();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(_profileProvider);

    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => mainScaffoldKey.currentState?.openDrawer(), tooltip: 'Abrir menu'),
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditSheet(
              context,
              ref,
              profileAsync.valueOrNull,
              fullName,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: _Avatar(url: avatarUrl, name: fullName ?? email),
          ),
          const SizedBox(height: 16),
          if (fullName != null && fullName.isNotEmpty)
            Center(
              child: Text(
                fullName,
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Center(
            child: Text(
              email,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),

          // Dados do perfil
          profileAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              if (profile == null) { return const SizedBox.shrink(); }
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          profile.bio!,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (profile.yearlyGoal != null)
                      _InfoChip(
                        icon: Icons.flag_rounded,
                        label: 'Meta: ${profile.yearlyGoal} livros/ano',
                      ),
                    if (profile.favoriteGenre != null)
                      _InfoChip(
                        icon: Icons.menu_book_outlined,
                        label: 'Gênero favorito: ${profile.favoriteGenre}',
                      ),
                    if (profile.favoriteBook != null && profile.favoriteBook!.isNotEmpty)
                      _InfoChip(
                        icon: Icons.auto_stories_outlined,
                        label: 'Livro favorito: ${profile.favoriteBook}',
                      ),
                    if (profile.favoriteAuthors != null && profile.favoriteAuthors!.isNotEmpty)
                      _InfoChip(
                        icon: Icons.person_outline_rounded,
                        label: 'Autores favoritos: ${profile.favoriteAuthors}',
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    String? displayName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(
        profile: profile,
        displayName: displayName,
        onSaved: () => ref.invalidate(_profileProvider),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.forestGreen),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

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
        backgroundColor: AppColors.forestGreen.withValues(alpha: 0.12),
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
      backgroundColor: AppColors.forestGreen,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.58,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final UserProfile? profile;
  final String? displayName;
  final VoidCallback onSaved;

  const _EditProfileSheet({
    required this.profile,
    required this.displayName,
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile?.name ?? widget.displayName ?? '',
    );
    _bioController = TextEditingController(text: widget.profile?.bio ?? '');
    _yearlyGoalController = TextEditingController(
      text: widget.profile?.yearlyGoal?.toString() ?? '',
    );
    _genreController = TextEditingController(
      text: widget.profile?.favoriteGenre ?? '',
    );
    _authorsController = TextEditingController(
      text: widget.profile?.favoriteAuthors ?? '',
    );
    _favoriteBookController = TextEditingController(
      text: widget.profile?.favoriteBook ?? '',
    );
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

  Future<void> _save(WidgetRef ref) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(profileRepositoryProvider).upsert({
        'name': _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'yearly_goal': int.tryParse(_yearlyGoalController.text.trim()),
        'favorite_genre': _genreController.text.trim().isEmpty
            ? null
            : _genreController.text.trim(),
        'favorite_authors': _authorsController.text.trim().isEmpty
            ? null
            : _authorsController.text.trim(),
        'favorite_book': _favoriteBookController.text.trim().isEmpty
            ? null
            : _favoriteBookController.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar perfil', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome de exibição'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe seu nome de exibição';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 2,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Biografia (opcional)'),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _yearlyGoalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Meta anual de livros'),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) {
                      return 'Informe um número maior que zero';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genreController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Gênero favorito (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _favoriteBookController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Livro favorito (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorsController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Autores favoritos (opcional)',
                  hintText: 'Ex: Machado de Assis, Clarice Lispector',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : () => _save(ref),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
