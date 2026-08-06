# Lumen — Plano de Migração e Implementação

## Visão Geral

Migração completa da UI do app Lumen em 9 fases, do sistema de design legado (ReadLog*) para o
sistema Lumen (LumenColors, LumenType, LumenTheme e componentes Lumen*). O trabalho é ordenado
pelo princípio de desbloqueio: cada fase libera a próxima. Fases que não foram iniciadas não devem
ser tocadas até que as fases anteriores estejam com `flutter analyze` limpo e com print real da
tela aprovado.

**Regra de conclusão de fase:** `flutter analyze` limpo + print real da tela aprovado pelo
desenvolvedor antes de marcar como concluída.

---

## Diagnóstico do estado atual (baseado em inspeção real do código)

**Já feito e correto:**
- `LumenTheme.light()`/`dark()` é o `ThemeData` ativo no `MaterialApp` — nenhuma ação necessária
- `ReadLogColors` e `ReadLogType` são `typedef` funcionais — compilam sem erro
- `flutter_svg ^2.1.0` no `pubspec.yaml`, `assets/icons/` mapeado com SVGs próprios
- `LumenMotion` já tem `duration/fast/slow/curve/curveOut/skelPulse` sem aliases antigos
- `ClubMomentBanner` já foi reescrito: sem `FilledButton`, sem `Border.all`, usa `LumenType.mono` com `w500`
- `LumenHallOfFamePodium` já implementado, ordem 2º-1º-3º correta, cores apenas de `LumenColors`
- `LumenClubTintBackground` já implementado e em uso
- `LumenUnlockBanner` e `LumenSpoilerNote` já usados em `milestone_discussion_screen.dart`
- `club_theories_screen.dart` já usa `LumenTheoryRow` com 3 estados narrativos
- `club_ranking_screen.dart` já tem 2 abas, `_MyPositionBlock`, usa `LumenAvatar`, `LumenType`, `LumenColors`
- `challenge_detail_screen.dart` já tem caption "Todos os N membros", avatares sobrepostos, dias de descanso
- `home_screen.dart` já tem streak em número grande (42px), presença do clube condicional, sem missões
- `profile_screen.dart` já tem `_StatItem`, `_LinkRow`, `_HeatmapSection` monocromático — estrutura correta
- `club_reading_room_screen.dart` já tem stat "leram juntos no clube"

**Trabalho restante real:**
- 26 arquivos usam `ReadLogColors.`/`ReadLogType.` em vez das classes diretas (migração mecânica)
- Conflito: `core/theme/app_theme.dart` e `lumen_compat.dart` declaram `AppColors` separadamente
- 3 call sites usam stubs: `ReadLogStamp` (achievements), `ReadLogCatalogCard` (library), `ReadLogReadingHeatmap` (dashboard)
- `palette_generator` ausente do `pubspec.yaml` (mas `LumenClubTintBackground` já funciona — verificar import real)
- `LumenPage` (transição GoRouter) não existe como widget público
- `LumenPressable` não existe
- Alguns Scaffolds não têm `LumenTexturedBackground` (a verificar)
- 4 ocorrências de `Border.all` no módulo clube para avaliar caso a caso
- `challenge_detail_screen.dart` usa `ReadLogColors.`/`ReadLogType.` (migração mecânica)
- `club_ranking_screen.dart` usa `_RankRow` local em vez de `LumenRankRow` público (baixa prioridade)
- Linha teaser de classificação na home do clube ainda não existe
- `LumenStatistic`, `LumenLinkRow`, `LumenHeatmap` não existem como classes públicas
  (equivalentes locais `_StatItem`, `_LinkRow`, `_HeatmapSection` já estão no profile_screen)
- `Hero` widget entre `LumenBookRow` e `BookDetailScreen` não implementado
- `HapticFeedback` não controlado (pode estar em lugares errados)
- Loading states podem ainda usar spinner colorido em alguns lugares
- Barras de progresso não animam o preenchimento

---

## Sub-Tarefa 1 — Resolver conflito AppColors e migrar aliases em lote

**Status:** [x] done

### Intent
Eliminar a duplicata de `AppColors` entre `core/theme/app_theme.dart` e `lumen_compat.dart`,
e fazer a migração mecânica de `ReadLogColors.` → `LumenColors.` e `ReadLogType.` → `LumenType.`
em todos os arquivos que ainda usam os aliases. Este é o desbloqueador para `flutter analyze` limpo.

### Expected Outcomes
- Nenhuma duplicata de `AppColors` no projeto
- Zero ocorrências de `ReadLogColors.` ou `ReadLogType.` fora de `lumen_theme.dart` e `lumen_compat.dart`
- `flutter analyze` sem warnings de deprecated ou redefinição
- Nenhuma tela quebra de compilação

### Todo List
1. Grep para confirmar quais arquivos importam `core/theme/app_theme.dart` (resultado esperado: 4 arquivos)
2. Verificar as diferenças de valor entre as duas declarações de `AppColors` (compat vs core/theme)
3. Fazer `core/theme/app_theme.dart` apenas re-exportar `lumen_compat.dart` — remover a declaração
   própria de `AppColors` e `AppTextStyles` do arquivo, mantendo apenas `AppTheme` (que já delega
   para `LumenTheme`)
4. Migração mecânica em lote nos 26 arquivos afetados:
   - `ReadLogColors.` → `LumenColors.`
   - `ReadLogType.` → `LumenType.`
5. Rodar `flutter analyze` e corrigir qualquer warning residual
6. Verificar se `ReadLogChip`, `ReadLogEventStamp`, `ReadLogPageHeader`, `ReadLogNotificationTile`,
   `ReadLogLeaderRow` têm call sites reais além dos stubs (grep separado)

### Relevant Context
- `mobile/lib/core/theme/app_theme.dart` — declaração própria de `AppColors` com valores ligeiramente diferentes do compat
- `mobile/lib/theme/lumen_compat.dart` — `AppColors`, `ReadLogChip`, `ReadLogEventStamp` e stubs
- 26 arquivos no módulo `clubs/` + `achievements/` + `dashboard/` com `ReadLogColors.`/`ReadLogType.`
- 4 arquivos importam `core/theme/app_theme.dart`: `reading_schedule_screen.dart`,
  `notification_settings_screen.dart`, `book_review_dialog.dart`, `invite_friend_sheet.dart`

---

## Sub-Tarefa 2 — Reescrever os 3 call sites de stubs

**Status:** [x] done

### Intent
Substituir as 3 chamadas de componentes-stub por suas implementações Lumen corretas. Os stubs
retornam `SizedBox.shrink()` — as telas simplesmente não mostram nada naquelas posições.

### Expected Outcomes
- `achievements_screen.dart`: seção de XP removida (gamificação proibida), tela visualmente correta
- `library_screen.dart`: `ReadLogCatalogCard` substituído por `LumenBookRow` (ou equivalente já existente)
- `dashboard_screen.dart`: `ReadLogReadingHeatmap` substituído por texto + linha fina monocromática
  (mesma abordagem usada no `profile_screen.dart` `_HeatmapSection`)

### Todo List
1. **achievements_screen.dart** — remover completamente o `ReadLogStamp` e seu container. Confirmar
   que a tela fica visualmente coerente sem o elemento de XP.
2. **library_screen.dart** — identificar qual widget Lumen substitui `ReadLogCatalogCard` (props:
   `title, author, progress, tabColor, coverUrl, currentPage, totalPages, onTap`). Verificar se
   `LumenBookRow` existe ou se é preciso criar.
3. **dashboard_screen.dart** — substituir `ReadLogReadingHeatmap(data: {date: minutes})` por
   representação textual monocromática. Consultar como `_HeatmapSection` do profile_screen.dart
   renderiza os dados de atividade.
4. Rodar `flutter analyze` após cada substituição.

### Relevant Context
- `mobile/lib/features/achievements/presentation/screens/achievements_screen.dart` linhas 138-149
- `mobile/lib/features/library/presentation/screens/library_screen.dart` linhas 359-368
- `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart` linhas 182-187
- `mobile/lib/theme/lumen_compat.dart` — stubs com comentários explicando a migração esperada
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart` — `_HeatmapSection` como referência

---

## Sub-Tarefa 3 — Verificar palette_generator e LumenClubTintBackground

**Status:** [x] done

### Intent
`LumenClubTintBackground` usa extração de cor dominante da capa do livro. O grep mostrou que
`palette_generator` não está no `pubspec.yaml`. Se o widget compila e funciona, provavelmente usa
outro mecanismo — confirmar o import real antes de adicionar dependência desnecessária.

### Expected Outcomes
- Dependência `palette_generator` adicionada ao `pubspec.yaml` se for realmente importada
- OU confirmação de que `LumenClubTintBackground` usa outra abordagem e não há ação necessária
- Sem runtime crash em telas de clube

### Todo List
1. Ler `lumen_theme.dart` linhas 1638-1685 (implementação de `_LumenClubTintBackgroundState`)
   para identificar o import exato usado para extração de cor
2. Se for `palette_generator`: adicionar ao `pubspec.yaml` (versão mais recente estável)
3. Se for outro mecanismo: documentar no arquivo de plano e marcar como OK
4. Rodar `flutter pub get` após qualquer mudança no `pubspec.yaml`

### Relevant Context
- `mobile/lib/theme/lumen_theme.dart` linha 1620-1684
- `mobile/pubspec.yaml`

---

## Sub-Tarefa 4 — Avaliar e corrigir Border.all no módulo clube

**Status:** [x] done

### Intent
As 4 ocorrências de `Border.all` identificadas no módulo clube têm propósitos distintos (não são
todas cards com borda simulando elevação). Cada uma precisa de avaliação independente antes de
qualquer alteração.

### Expected Outcomes
- Cada `Border.all` ou é convertido para `Divider`/sem borda, ou é mantido com justificativa
  documentada (ex: input de autocomplete com borda tem propósito funcional de delimitar área)
- Nenhum card com `Container + Border.all + fundo colorido` simulando elevação no módulo clube

### Todo List
1. **book_club_detail_screen.dart linha 2637** — Container de autocomplete (sugestões de livros):
   avaliar se a borda serve como demarcador funcional de input ou se pode ser `InputDecoration` nativa
2. **book_club_detail_screen.dart linha 2911** — Container de lista de sugestões rolável:
   idem acima — avaliar se é estruturalmente necessário
3. **book_club_detail_screen.dart linha 3669** — Card de resultado de poll (enquete):
   verificar visualmente com print antes de decidir; se for simulação de elevação converter para
   Divider acima e abaixo; se for delimitação funcional de conteúdo distinto, manter
4. **club_checkin_screen.dart linha 155** — Chip de seleção de humor (mood selector):
   borda muda com seleção (ink vs inkGhost) — este caso tem propósito funcional claro e DEVE
   ser mantido. Apenas migrar `ReadLogColors.ink`/`ReadLogColors.inkGhost` → `LumenColors.*`
5. Verificar visualmente cada mudança com print

### Relevant Context
- `mobile/lib/features/clubs/presentation/screens/book_club_detail_screen.dart` linhas 2630-2670, 2900-2925, 3660-3680
- `mobile/lib/features/clubs/presentation/screens/club_checkin_screen.dart` linhas 145-165

---

## Sub-Tarefa 5 — Criar LumenPage e LumenPressable

**Status:** [x] done

### Intent
Completar a Fase 1 criando os dois widgets que ainda não existem: `LumenPage` para transições
de rota e `LumenPressable` para CTAs principais. Ambos já têm toda a infraestrutura disponível
(`_FadeSlidePageTransitionsBuilder` e `LumenMotion` já implementados).

### Expected Outcomes
- Todas as rotas do GoRouter usam `LumenPage` via `pageBuilder:` — transição consistente
- CTAs principais (continuar leitura, confirmar check-in, confirmar leitura) usam `LumenPressable`
- Nenhuma rota usa `builder:` padrão do GoRouter (exceto admin)

### Todo List
1. Criar `LumenPage<T>` em `lumen_theme.dart`:
   - Wrapper de `CustomTransitionPage<T>` que usa `_FadeSlidePageTransitionsBuilder`
   - Assinatura: `LumenPage({required Widget child, LocalKey? key})`
2. No `app_router.dart`, converter todas as rotas de `builder: (_, __) => Widget` para
   `pageBuilder: (_, __, __) => LumenPage(child: Widget)` — exceto rotas admin que ficam em `builder:`
3. Criar `LumenPressable` em `lumen_theme.dart`:
   - Wrapper de `GestureDetector` com `ScaleTransition` de 0.97 ao pressionar
   - Parâmetros: `child`, `onTap`, `haptic` (bool, default false)
4. Aplicar `LumenPressable` nos CTAs: botão de continuar leitura em `home_screen.dart`,
   confirmar em `club_checkin_screen.dart`, confirmar leitura em `club_moment_banner.dart`
5. Verificar print real de transição entre telas

### Relevant Context
- `mobile/lib/theme/lumen_theme.dart` — `_FadeSlidePageTransitionsBuilder` (linha 853), `LumenMotion` (linha 457)
- `mobile/lib/core/router/app_router.dart` — todas as rotas `ShellRoute` e `GoRoute`

---

## Sub-Tarefa 6 — Verificar cobertura de LumenTexturedBackground

**Status:** [x] done

### Intent
Confirmar que todos os `Scaffold` com `body` exposto têm `LumenTexturedBackground` envolvendo.
O grep mostrou 28 telas com o widget, mas o projeto tem mais telas.

### Expected Outcomes
- Todos os Scaffolds de telas de feature têm `LumenTexturedBackground` no `body`
- Telas admin e telas de loading/erro simples são exceção documentada

### Todo List
1. Grep por `Scaffold(` em todo `mobile/lib/features/` e `mobile/lib/core/`
2. Cruzar com grep por `LumenTexturedBackground` nos mesmos arquivos
3. Para cada Scaffold sem `LumenTexturedBackground`: adicionar o wrapper no body
4. Exceções aceitáveis: tela de erro de configuração (`_ConfigErrorApp` em `main.dart`),
   telas admin, splash screen
5. Verificar print real de pelo menos 3 telas que receberam o wrapper

### Relevant Context
- `mobile/lib/theme/lumen_theme.dart` linha 1401 — `LumenTexturedBackground`
- `mobile/lib/main.dart` linha 204 — `_ConfigErrorApp` (exceção documentada)

---

## Sub-Tarefa 7 — Adicionar linha teaser de classificação na home do clube

**Status:** [x] done

### Intent
A home do clube (`book_club_detail_screen.dart`) ainda não tem a linha teaser de classificação
("Classificações — 1º Marcelle · 14 ✓"). O `_clubReadingNowProvider` já existe e o
`club_ranking_screen.dart` já tem todos os dados necessários.

### Expected Outcomes
- Linha "Classificações — 1º [nome] · N ✓" visível na home do clube quando há dados
- Toca em `club_ranking_screen.dart`
- Linha ausente quando não há dados de ranking (condicional)

### Todo List
1. Criar provider `_clubRankingTeaserProvider` em `book_club_detail_screen.dart` que busca
   apenas a posição 1 do ranking (já existe `fetchClubRanking` no repositório)
2. Renderizar a linha no bloco da home do clube, abaixo da seção de desafio e acima de presença
3. Formato: `'Classificações — 1º ${firstName} · ${checkinDays} ✓'`
4. Toque navega para `club_ranking_screen.dart`
5. Linha oculta (SizedBox.shrink) se não houver dados

### Relevant Context
- `mobile/lib/features/clubs/presentation/screens/book_club_detail_screen.dart`
- `mobile/lib/features/clubs/presentation/screens/club_ranking_screen.dart`
- `mobile/lib/features/clubs/data/book_club_repository.dart` — método de ranking existente

---

## Sub-Tarefa 8 — Corrigir título automático do desafio por goal_type

**Status:** [x] done

### Intent
Em `challenge_detail_screen.dart`, o título é passado como parâmetro `challengeTitle` — o que
significa que quem chama a tela controla o título. A spec exige título automático a partir do
`goal_type`, nunca pergunta comparativa tipo "Quem lê mais?".

### Expected Outcomes
- Título gerado internamente com base em `challenge.goalType`, não no parâmetro externo
- Nenhum título comparativo possível de aparecer

### Todo List
1. Ler `challenge_detail_screen.dart` inteiro para entender como `challengeTitle` é passado
2. Verificar enum `GoalType` (ou equivalente) no modelo `ClubChallenge` — quais são os valores
3. Criar mapa `GoalType → String` em português neutro (ex: `pagesRead → 'Páginas lidas no clube'`)
4. Substituir o uso de `challengeTitle` pelo título gerado
5. Verificar o call site em `book_club_detail_screen.dart` que passa `challengeTitle`

### Relevant Context
- `mobile/lib/features/clubs/presentation/screens/challenge_detail_screen.dart` linhas 78-97
- `mobile/lib/shared/models/club_schedule_milestones_challenges.dart` — modelo `ClubChallenge`

---

## Sub-Tarefa 9 — Fase 7: Tornar LumenStatistic, LumenLinkRow, LumenHeatmap públicos

**Status:** [x] done

### Intent
`profile_screen.dart` já tem `_StatItem`, `_LinkRow` e `_HeatmapSection` locais com a aparência
correta. Promover apenas `LumenHeatmap` para componente público em `lumen_theme.dart` — é o mais
provável de ser reutilizado (dashboard, member_profile). `_StatItem` e `_LinkRow` permanecem
locais até outra tela precisar — YAGNI. Rever profile contra `lumen-perfil.html` e substituir
ícones Material por `LumenIcon`.

### Expected Outcomes
- `LumenHeatmap` declarado em `lumen_theme.dart` (extraído de `_HeatmapSection`)
- `profile_screen.dart` usa `LumenHeatmap`; `_StatItem` e `_LinkRow` permanecem locais
- Ícones do perfil migrados de `Icons.*` Material para o set SVG próprio onde houver equivalente

### Todo List
1. Ler `lumen-perfil.html` (se disponível em `mobile/docs/`) para identificar divergências visuais
2. Extrair `_HeatmapSection` → `LumenHeatmap` em `lumen_theme.dart`; manter `_StatItem` e `_LinkRow` locais
3. Substituir `_HeatmapSection` no `profile_screen.dart` por `LumenHeatmap`
4. Auditar ícones `Icons.` no profile e substituir pelos equivalentes de `assets/icons/` via `LumenIcon`
5. Verificar print real do perfil

### Relevant Context
- `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- `mobile/lib/theme/lumen_theme.dart` — `LumenIcon` (linha 1297), padrão dos outros widgets públicos
- `mobile/docs/` — verificar se `lumen-perfil.html` existe

---

## Sub-Tarefa 10 — Fase 9 (Polish): Hero, HapticFeedback, Skeletons, Animação de progresso

**Status:** [x] done

### Intent
Polimento final de UX. Executar somente depois que todas as fases anteriores estiverem com
`flutter analyze` limpo e print aprovado.

### Expected Outcomes
- `Hero` na capa do livro entre `LumenBookRow`/`LumenBookHero` e `BookDetailScreen`
- `HapticFeedback.lightImpact()` apenas em: conclusão de check-in e desbloqueio de marco
- Loading states usando shimmer (retângulo cinza pulsando), sem spinner colorido
- Barras de progresso animam o preenchimento em 300-400ms ao valor mudar

### Todo List
1. **Hero widget**: adicionar `heroTag` na capa em `library_screen.dart` e no destino em
   `book_detail_screen.dart`. Tag = `'book-cover-${book.id}'`
2. **HapticFeedback**: grep por `HapticFeedback` em todo o projeto para inventariar uso atual.
   Manter apenas nos 2 pontos aprovados; remover o restante.
3. **Skeletons**: grep por `CircularProgressIndicator` em telas de feature (não em botões de
   loading). Substituir por `Shimmer.fromColors` (pacote `shimmer` já no pubspec) com retângulo
   de altura equivalente ao conteúdo que vai aparecer.
4. **Animação de barras**: substituir `LumenReadingProgress` por versão animada usando
   `AnimatedFraction` ou `TweenAnimationBuilder<double>` que anima de valor anterior para
   valor novo em `LumenMotion.duration` (220ms) com `LumenMotion.curve`
5. Verificar print real de cada um dos 4 itens

### Relevant Context
- `mobile/lib/features/library/presentation/screens/library_screen.dart`
- `mobile/lib/features/library/presentation/screens/book_detail_screen.dart`
- `mobile/lib/theme/lumen_theme.dart` linha 949 — `LumenReadingProgress`
- `mobile/pubspec.yaml` — pacote `shimmer ^3.0.0` já presente

---

## Ordem de execução

```
ST-1 (alias + AppColors)
  → ST-2 (stubs)
    → ST-3 (palette_generator)
      → ST-4 (Border.all)
        → flutter analyze limpo ← Gate obrigatório
          → ST-5 (LumenPage + LumenPressable)
            → ST-6 (LumenTexturedBackground cobertura)
              → ST-7 (teaser ranking)
                → ST-8 (título desafio)
                  → ST-9 (widgets públicos — Fase 7)
                    → ST-10 (polish — Fase 9)
```

Fases 8 (Home pessoal) e 5 (Desafio reorganizado) já têm a maioria dos itens implementados —
após ST-1 (que cobre a migração mecânica de `ReadLogColors.*` em `challenge_detail_screen.dart`)
essas fases estarão efetivamente concluídas e só precisam de verificação com print real.
