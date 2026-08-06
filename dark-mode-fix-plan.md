# Plano: Suporte Completo a Dark Mode e Toggle de Tema

## Visão Geral

O app já possui `LumenTheme.light()` e `LumenTheme.dark()` configurados no `MaterialApp.router`, mas várias telas usam **cores hardcoded** (estáticas de `AppColors.*` e `Colors.white`) que não mudam com o tema. O resultado é fundo claro aparecendo no dark mode e texto ilegível.

Além disso, hoje o app usa `ThemeMode.system` sem dar opção ao usuário de escolher manualmente. O objetivo é:

1. Criar um provider `themeModeProvider` persistido em `SharedPreferences`.
2. Conectar o `MaterialApp.router` a esse provider.
3. Adicionar toggle de tema na tela de Configurações (dentro de `_SettingsSheet` no perfil).
4. Corrigir todas as telas/widgets com cores hardcoded para usar tokens do tema.

---

## Sub-Tarefas

---

### Sub-tarefa 1 — Provider de ThemeMode persistido

**Status:** `[ ] pending`

**Intent**
Criar um `themeModeProvider` (Riverpod `StateNotifierProvider` ou `NotifierProvider`) que lê e persiste o `ThemeMode` escolhido via `SharedPreferences`. O `main.dart` passa a observar esse provider para alimentar o `MaterialApp.router`.

**Expected Outcomes**
- `lib/theme/theme_mode_provider.dart` criado com o provider.
- `main.dart` (`ReadlogApp.build`) lê o provider e passa ao `themeMode:`.
- Escolha do usuário sobrevive ao reinício do app.

**Todo List**
1. Criar `mobile/lib/theme/theme_mode_provider.dart` com `ThemeModeNotifier extends Notifier<ThemeMode>`.
2. No `ThemeModeNotifier.build()` carregar o valor de `SharedPreferences` (chave `'theme_mode'`); padrão: `ThemeMode.system`.
3. Expor método `setMode(ThemeMode)` que atualiza state e salva na prefs.
4. Em `main.dart`, no `ReadlogApp.build`, trocar `themeMode: ThemeMode.system` por `themeMode: ref.watch(themeModeProvider)`.
5. Remover o comentário que diz "segue sempre ThemeMode.system".

**Relevant Context**
- [`main.dart`](mobile/lib/main.dart:178) — linha 178, `themeMode: ThemeMode.system`.
- [`theme_controller.dart`](mobile/lib/theme/theme_controller.dart) — arquivo quase vazio, pode ganhar re-export do novo provider.
- `shared_preferences` já é dependência do projeto (verificar `pubspec.yaml` antes).

---

### Sub-tarefa 2 — Toggle de tema em Configurações

**Status:** `[ ] pending`

**Intent**
Adicionar um `ListTile` com ícone de tema e um `DropdownButton` (ou 3 `ChoiceChip`: Sistema / Claro / Escuro) dentro do `_SettingsSheet` da tela de perfil, que chama `ref.read(themeModeProvider.notifier).setMode(...)`.

**Expected Outcomes**
- O usuário consegue escolher entre "Sistema", "Claro" e "Escuro" em Configurações.
- A mudança é imediata e visual.
- O estado persiste após fechar e reabrir o app.

**Todo List**
1. Em `profile_screen.dart`, importar o `themeModeProvider`.
2. Converter `_SettingsSheet` de `ConsumerWidget` para `ConsumerWidget` (já é — garantir acesso ao `ref`).
3. Adicionar tile de "Tema" antes do `Divider` no `_SettingsSheet.build`, com 3 opções de seleção (ChoiceChip ou SegmentedButton).
4. Chamar `ref.read(themeModeProvider.notifier).setMode(...)` ao selecionar.

**Relevant Context**
- [`profile_screen.dart`](mobile/lib/features/profile/presentation/screens/profile_screen.dart:968) — `_SettingsSheet` linha 968.
- [`profile_screen.dart`](mobile/lib/features/profile/presentation/screens/profile_screen.dart:1011) — `Divider` antes de Sair, linha 1011.

---

### Sub-tarefa 3 — Corrigir onboarding_screen.dart

**Status:** `[ ] pending`

**Intent**
Todas as cores estáticas (`AppColors.surface`, `AppColors.border`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.offWhite`) dentro do onboarding precisam ser substituídas por tokens do `Theme.of(context)` ou `LumenColors` corretos por tema.

**Expected Outcomes**
- `backgroundColor: AppColors.offWhite` no Scaffold usa `Theme.of(context).scaffoldBackgroundColor`.
- Containers de seleção de perfil e chips de tipo usam `cs.surface` e `cs.outline`.
- Textos secundários usam `cs.onSurface` com opacidade ou `Theme.of(context).textTheme.bodyMedium`.
- `_GenreSelector` `FilterChip.backgroundColor` usa `cs.surface`.
- Barra de progresso usa `cs.outline` como background.

**Todo List**
1. No `_OnboardingScreenState.build`, remover `backgroundColor: AppColors.offWhite` (o `LumenTexturedBackground` + Scaffold já usam `scaffoldBackgroundColor` do tema).
2. Em `_WelcomePage.build`, substituir referências a `AppTextStyles.*` estáticas por `Theme.of(context).textTheme.*` onde a cor estiver hardcoded.
3. Em `_ReaderProfileSelector`, trocar `AppColors.surface` → `cs.surface`, `AppColors.border` → `cs.outline`.
4. Em `_TypeChip`, mesma substituição.
5. Em `_GenreSelector` (`FilterChip`), trocar `backgroundColor: AppColors.surface` → `cs.surface`.
6. Em `_OnboardingHeader`, trocar `backgroundColor: AppColors.border` → `cs.outline` na barra de progresso.
7. Substituir `AppColors.textSecondary`, `AppColors.textPrimary` por `cs.onSurface` (com/sem opacidade conforme hierarquia).

**Relevant Context**
- [`onboarding_screen.dart`](mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart:204)
- `AppColors.surface` → `LumenColors.surface` (estático light) — precisa virar dinâmico via `cs.surface`.
- `AppColors.border` → `LumenColors.hairline` (estático) — precisa virar `cs.outline`.

---

### Sub-tarefa 4 — Corrigir add_book_screen.dart e edit_book_screen.dart

**Status:** `[ ] pending`

**Intent**
A tela de adição e edição de livros usa `AppColors.surface`, `AppColors.border`, `AppColors.textMuted` hardcoded em `Container` de sugestões e no widget de capa.

**Expected Outcomes**
- Container de sugestões usa `cs.surface` e borda `cs.outline`.
- Ícone de fallback de capa usa `cs.outline` e `cs.onSurface` com opacidade.
- `_SuggestionTile` usa cores do tema.

**Todo List**
1. Em `add_book_screen.dart`, no `Container` de sugestões (linha 237–250), trocar `AppColors.surface` → `cs.surface`, `AppColors.border` → `cs.outline`.
2. No `errorWidget` da capa selecionada, trocar `AppColors.border` → `cs.surfaceContainerHighest`, ícone `AppColors.textMuted` → `cs.onSurface.withOpacity(0.4)`.
3. Em `_SuggestionTile`, trocar todos os `AppColors.*` por `cs.*` equivalentes.
4. Repetir ajustes em `edit_book_screen.dart` nas mesmas ocorrências.

**Relevant Context**
- [`add_book_screen.dart`](mobile/lib/features/library/presentation/screens/add_book_screen.dart:237)
- [`edit_book_screen.dart`](mobile/lib/features/library/presentation/screens/edit_book_screen.dart:157)

---

### Sub-tarefa 5 — Corrigir telas com `backgroundColor: Colors.white` e `AppColors.offWhite`

**Status:** `[ ] pending`

**Intent**
Diversas telas usam `Colors.white` em `showModalBottomSheet` e `backgroundColor: AppColors.offWhite` em Scaffolds, que ficam sempre claros no dark mode.

**Expected Outcomes**
- `backgroundColor: Colors.white` em bottom sheets e diálogos vira `cs.surface`.
- `backgroundColor: AppColors.offWhite` em Scaffolds vira `Theme.of(context).scaffoldBackgroundColor`.

**Todo List**
1. `goals_screen.dart` linha 40 — `Colors.white` → `cs.surface`.
2. `highlights_screen.dart` linha 50 — `Colors.white` → `cs.surface`.
3. `wishlist_screen.dart` linha 40 — `Colors.white` → `cs.surface`.
4. `friends_screen.dart` linha 121 — `Colors.white` → `cs.surface`.
5. `book_club_detail_screen.dart` linhas 524, 539, 558, 3313 — `Colors.white` → `cs.surface`.
6. `reading_schedule_screen.dart` linha 108 — `AppColors.offWhite` → `Theme.of(context).scaffoldBackgroundColor`.
7. `notification_settings_screen.dart` linha 17 — mesmo ajuste.
8. `friend_profile_screen.dart` linhas 47/49 — mesmo ajuste.

**Relevant Context**
- Todos os arquivos listados em `mobile/lib/features/`.

---

### Sub-tarefa 6 — Corrigir session_history, notes, social e outras telas com AppColors estáticos

**Status:** `[ ] pending`

**Intent**
Telas de histórico de sessão, notas, social e notificações usam `AppColors.surface`, `AppColors.border`, `AppColors.textPrimary`, `AppColors.textMuted` em Containers e Dividers hardcoded que não respondem ao dark mode.

**Expected Outcomes**
- Todos os `Container` com `color: AppColors.surface` usam `cs.surface` ou `cs.surfaceContainerHighest`.
- `Border.all(color: AppColors.border)` usa `cs.outline`.
- Textos e ícones com `AppColors.textMuted` / `AppColors.textSecondary` usam `cs.onSurface` com opacidade adequada.

**Todo List**
1. `session_history_screen.dart` — linhas 126–168.
2. `notes_screen.dart` — linhas 106–141.
3. `social_screen.dart` — linhas 234–853 (varredura + substituições).
4. `notification_settings_screen.dart` — linhas 34–269.
5. `reading_schedule_screen.dart` — linhas 145–301.
6. `book_detail_screen.dart` — Dividers com `AppColors.border` e barra de progresso.
7. Verificar `book_club_detail_screen.dart` restante (linhas 2468–2994).

**Relevant Context**
- Padrão de correção: `AppColors.surface` → `cs.surface`, `AppColors.border` → `cs.outline`, `AppColors.textMuted` → `cs.onSurface.withValues(alpha: 0.5)`.

---

## Referência de Mapeamento de Cores

| Cor hardcoded | Token dinâmico equivalente |
|---|---|
| `AppColors.surface` / `AppColors.offWhite` | `cs.surface` |
| `AppColors.border` | `cs.outline` |
| `AppColors.textPrimary` | `cs.onSurface` |
| `AppColors.textSecondary` | `cs.onSurface.withValues(alpha: 0.65)` |
| `AppColors.textMuted` | `cs.onSurface.withValues(alpha: 0.45)` |
| `Colors.white` em backgrounds | `cs.surface` |
| `AppColors.offWhite` em Scaffold | `Theme.of(context).scaffoldBackgroundColor` |
| `AppColors.forestGreen` | `cs.secondary` (já mapeado no theme) |
