# Plano — Módulo Clube: Conformidade com Lumen DS

## Visão Geral

O módulo Clube já existe com as 13 telas definidas no Lumen DS. A grande maioria dos arquivos
está em conformidade com o design system. O único arquivo com violações significativas é
`book_club_detail_screen.dart`, que mistura tokens legado (`AppColors`, `AppTextStyles`) com
os tokens Lumen atuais.

**Objetivo:** Trazer o módulo Clube para conformidade total com o Lumen DS, sem adicionar
funcionalidades novas nem refatorar o que já está correto.

**Escopo do problema:**
- `book_club_detail_screen.dart` — 48 ocorrências de `AppColors` / `AppTextStyles` a migrar
- Alguns usos de `border: Border.all()` em cards que violam a regra "nenhum card com borda"
- Um uso de `CircularProgressIndicator` na tela de carregamento inicial (linha 94)
- Todas as outras 12 telas + 4 widgets já estão em conformidade

---

## Sub-Tarefas

### Sub-tarefa 1 — Migrar cores e tipografia legado em `book_club_detail_screen.dart`

- **Status:** `[ ] pendente`

**Intent:** Substituir todas as referências a `AppColors` e `AppTextStyles` pelos equivalentes
canônicos `LumenColors` e `LumenType`, garantindo que o arquivo maior do módulo use somente
os tokens do design system.

**Expected Outcomes:**
- Zero ocorrências de `AppColors` e `AppTextStyles` no arquivo
- O arquivo compila sem erros ou avisos novos
- Aparência visual preservada — apenas substituição de token, sem mudança de layout

**Todo List:**
1. Substituir `AppColors.error` → `LumenColors.danger` (15 ocorrências, linhas: 485, 487, 636, 1278, 1280, 1377, 1570, 1594, 1616, 1641, 1678, 1720, 2230, 2232, 2361)
2. Substituir `AppColors.border` → `LumenColors.hairline` (linhas: 2468, 2637, 2911, 2994, 3659)
3. Substituir `AppColors.surface` → `LumenColors.surface` (linhas: 2635, 2909)
4. Substituir `AppColors.textMuted` → `LumenColors.inkMuted` (linhas: 2667, 2677, 2727, 2938, 2947, 2996)
5. Substituir `AppColors.forestGreen` → `LumenColors.read` (linha: 3035)
6. Substituir `AppColors.warmGold` → `LumenColors.warning` (linha: 3588)
7. Substituir `AppColors.darkSurface` → `LumenColors.canvasVariant` (linha: 3658)
8. Substituir `AppColors.darkBorder` → `LumenColors.hairlineDark` (linha: 3659)
9. Substituir `AppColors.darkTextPrimary` → `LumenColors.inkInverse` (se presente)
10. Substituir `AppTextStyles.headlineMedium` → `LumenType.textTheme(cs.onSurface).headlineMedium` (ou `Theme.of(context).textTheme.headlineMedium`) (linhas: 2474, 2878, 3151, 3516, 3828, 4191)
11. Substituir `AppTextStyles.bodyLarge` → `Theme.of(context).textTheme.bodyLarge` (linhas: 2491)
12. Substituir `AppTextStyles.bodyMedium` → `Theme.of(context).textTheme.bodyMedium` (linhas: 2692, 2960, 3003)
13. Substituir `AppTextStyles.titleMedium` → `Theme.of(context).textTheme.titleMedium` (linhas: 2687, 2955, 3679)
14. Substituir `AppTextStyles.labelMedium` → `Theme.of(context).textTheme.labelSmall` (linhas: 3537, 3839)

**Relevant Context:**
- [`book_club_detail_screen.dart`](mobile/lib/features/clubs/presentation/screens/book_club_detail_screen.dart)
- [`lumen_theme.dart`](mobile/lib/theme/lumen_theme.dart) — `LumenColors`, `LumenType`
- [`lumen_compat.dart`](mobile/lib/theme/lumen_compat.dart) — `AppColors` e `AppTextStyles` são shims legado; os equivalentes Lumen estão definidos lá
- [`app_theme.dart`](mobile/lib/core/theme/app_theme.dart) — segunda fonte de shims legado

---

### Sub-tarefa 2 — Remover bordas de card em `book_club_detail_screen.dart`

- **Status:** `[ ] pendente`

**Intent:** Remover `border: Border.all(...)` em containers que representam cards, conforme a
regra do Lumen DS: "nenhum card com borda visível — separação sempre por divisor ou espaço
em branco".

**Expected Outcomes:**
- Nenhum `BoxDecoration(border: Border.all(...))` em cards no arquivo
- Separação visual mantida por espaço/divisor quando necessário

**Todo List:**
1. Linha 2637: remover `border: Border.all(color: ...)` do card de opções de livro
2. Linha 2911: remover `border: Border.all(color: ...)` do card de livro atual
3. Linha 3659–3670: remover `border: Border.all(color: ...)` do `_OpenPollCard`
4. Verificar se a remoção das bordas prejudica a separação visual; se sim, adicionar `SizedBox` ou `Divider` com `LumenColors.hairline`

**Relevant Context:**
- [`book_club_detail_screen.dart`](mobile/lib/features/clubs/presentation/screens/book_club_detail_screen.dart:2635)
- Regra DS: separação por `LumenColors.hairline` / `LumenColors.divider`, nunca `BoxDecoration(border: ...)`

---

### Sub-tarefa 3 — Substituir `CircularProgressIndicator` pelo `LumenGrainLoader` no estado de carregamento inicial

- **Status:** `[ ] pendente`

**Intent:** A regra do Lumen DS proíbe spinner colorido como estado de loading. O estado
inicial de carregamento de `BookClubDetailScreen` (linha 94) exibe `CircularProgressIndicator`,
que deve ser substituído por `LumenGrainLoader`.

**Expected Outcomes:**
- Estado de loading da tela principal usa `LumenGrainLoader` em vez de `CircularProgressIndicator`
- Mesma estrutura de `Scaffold` preservada

**Todo List:**
1. Localizar o bloco `loading: () => Scaffold(...)` em `BookClubDetailScreen.build` (linha ~92)
2. Substituir `Center(child: CircularProgressIndicator())` por `LumenGrainLoader.wrap(child: const SizedBox.shrink())` ou simplesmente `const Center(child: LumenGrainLoader())`

**Relevant Context:**
- [`book_club_detail_screen.dart`](mobile/lib/features/clubs/presentation/screens/book_club_detail_screen.dart:92)
- [`lumen_theme.dart`](mobile/lib/theme/lumen_theme.dart:1491) — `LumenGrainLoader` e seu método estático `wrap`

---

### Sub-tarefa 4 — Verificação final de conformidade

- **Status:** `[ ] pendente`

**Intent:** Confirmar que nenhum arquivo do módulo Clube contém violações remanescentes do
Lumen DS após as sub-tarefas anteriores.

**Expected Outcomes:**
- `grep` por `AppColors|AppTextStyles` nos arquivos do módulo retorna zero resultados
- `flutter analyze` no projeto retorna sem erros novos
- As 13 telas carregam sem exceções em modo debug

**Todo List:**
1. Rodar `grep -r "AppColors\|AppTextStyles" mobile/lib/features/clubs/` — deve retornar vazio
2. Rodar `grep -r "CircularProgressIndicator" mobile/lib/features/clubs/` — revisar qualquer resultado
3. Rodar `grep -r "border: Border.all" mobile/lib/features/clubs/` — revisar qualquer resultado
4. Rodar `flutter analyze mobile/` e corrigir eventuais erros novos
5. Smoke-test manual nas telas do clube em light e dark mode

**Relevant Context:**
- Todas as telas em [`mobile/lib/features/clubs/presentation/screens/`](mobile/lib/features/clubs/presentation/screens/)

---

## Notas de Contexto

- `AppColors` e `AppTextStyles` são shims de compatibilidade definidos em dois lugares:
  [`lumen_compat.dart`](mobile/lib/theme/lumen_compat.dart) e
  [`app_theme.dart`](mobile/lib/core/theme/app_theme.dart). Eles delegam para `LumenColors`,
  mas têm valores ligeiramente diferentes para `textSecondary`, `textMuted`, `darkBorder`,
  `darkSurfaceVariant` — por isso a substituição deve ser feita token a token.

- `AppTextStyles` usa `IBM Plex Mono` como fonte padrão (`_bodyFont`), enquanto o Lumen DS
  usa `Inter` para corpo de texto. O `textTheme` gerado por `LumenTheme` já está correto.
  Ao substituir `AppTextStyles.bodyLarge` por `Theme.of(context).textTheme.bodyLarge`, a
  fonte passará a ser `Inter` conforme o DS.

- A sub-tarefa 2 (bordas) deve ser validada visualmente. Em alguns casos a borda pode
  estar sendo usada como separador legítimo de seção — nesses casos substituir por `Divider`
  com `color: LumenColors.hairline` e `height: 1`.
