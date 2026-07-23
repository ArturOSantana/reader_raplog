import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/club_stories_and_capsule.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/feed_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clubStoriesProvider =
    FutureProvider.family<List<ClubStory>, String>((ref, clubId) {
  return ref.read(bookClubRepositoryProvider).listStories(clubId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClubStoriesScreen extends ConsumerWidget {
  final String clubId;
  final String clubName;

  const ClubStoriesScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.offWhite;
    final storiesAsync = ref.watch(_clubStoriesProvider(clubId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stories',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(clubName,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Publicar story',
            onPressed: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
      body: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar os stories.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ),
        ),
        data: (stories) {
          if (stories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_outlined,
                        size: 48,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('Nenhum story ativo.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Text('Stories expiram após 24 horas.',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.45))),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showCreateSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Publicar o primeiro'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_clubStoriesProvider(clubId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _StoryCard(
                story: stories[i],
                onDelete: () async {
                  await ref
                      .read(bookClubRepositoryProvider)
                      .deleteStory(stories[i].id);
                  ref.invalidate(_clubStoriesProvider(clubId));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateStorySheet(
        clubId: clubId,
        onCreated: () => ref.invalidate(_clubStoriesProvider(clubId)),
      ),
    );
  }
}

// ── Card de Story ─────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final ClubStory story;
  final VoidCallback onDelete;

  const _StoryCard({required this.story, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              MiniAvatar(
                url: story.authorAvatar,
                name: story.authorName ?? '?',
                radius: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.authorName ?? 'Membro',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(story.timeLeftLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              _StoryTypeBadge(type: story.storyType),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
            ],
          ),
          // Conteúdo
          if (story.content != null && story.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(story.content!,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ],
          if (story.storyType == StoryType.image &&
              story.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                story.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: cs.surfaceContainerLowest,
                  child: Icon(Icons.broken_image_outlined,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
          if (story.bookTitle != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 16, color: AppColors.forestGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(story.bookTitle!,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.forestGreen,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
          if (story.caption != null && story.caption!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(story.caption!,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _StoryTypeBadge extends StatelessWidget {
  final StoryType type;
  const _StoryTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      StoryType.text         => ('Texto', AppColors.forestGreen),
      StoryType.image        => ('Foto', AppColors.warmGold),
      StoryType.bookProgress => ('Leitura', AppColors.forestGreenLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Sheet de criação ──────────────────────────────────────────────────────────

class _CreateStorySheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CreateStorySheet({required this.clubId, required this.onCreated});

  @override
  ConsumerState<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends ConsumerState<_CreateStorySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _textCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _textCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final xFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (xFile != null && mounted) {
        setState(() => _pickedImage = File(xFile.path));
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'photo_access_denied'
                  ? 'Permissão negada. Vá em Configurações e permita acesso à galeria.'
                  : 'Não foi possível abrir a galeria.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final isText = _tabs.index == 0;
    if (isText && _textCtrl.text.trim().isEmpty) return;
    if (!isText && _pickedImage == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(bookClubRepositoryProvider);
      if (isText) {
        await repo.createTextStory(
          clubId: widget.clubId,
          content: _textCtrl.text.trim(),
        );
      } else {
        await repo.createImageStory(
          clubId: widget.clubId,
          imageFile: _pickedImage!,
          caption: _captionCtrl.text.trim(),
        );
      }
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publicar Story',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: cs.onSurface)),
                const SizedBox(height: 4),
                Text('Visível por 24 horas para os membros do clube.',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Abas ────────────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.text_fields, size: 18), text: 'Texto'),
              Tab(icon: Icon(Icons.photo_camera_outlined, size: 18), text: 'Foto'),
            ],
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            onTap: (_) => setState(() {}),
          ),
          const Divider(height: 1),
          // ── Conteúdo da aba ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: _tabs.index == 0
                ? _TextTab(controller: _textCtrl)
                : _PhotoTab(
                    image: _pickedImage,
                    captionController: _captionCtrl,
                    onPick: _pickImage,
                  ),
          ),
          // ── Ações ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aba de texto ──────────────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  final TextEditingController controller;
  const _TextTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 5,
      minLines: 3,
      maxLength: 300,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'O que você quer compartilhar com o clube?',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Aba de foto ───────────────────────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  final File? image;
  final TextEditingController captionController;
  final VoidCallback onPick;

  const _PhotoTab({
    required this.image,
    required this.captionController,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prévia / botão de seleção
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: image != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(image!, fit: BoxFit.cover),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Trocar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: cs.onSurface.withValues(alpha: 0.35)),
                      const SizedBox(height: 8),
                      Text('Toque para escolher uma foto',
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Legenda opcional
        TextField(
          controller: captionController,
          maxLines: 2,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Legenda (opcional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
