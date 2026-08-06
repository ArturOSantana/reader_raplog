## Guia de Integração: Sistema de Amigos e Convites para Clubes

### 1. Usar a Tela de Gerenciamento de Membros

Para adicionar a tela de membros ao seu clube, integre o roteamento:

```dart
// No seu router
GoRoute(
  path: 'members',
  builder: (context, state) {
    final clubId = state.pathParameters['clubId']!;
    return ClubMembersScreen(clubId: clubId);
  },
)
```

Na AppBar do detalhe do clube:

```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.people_outline),
      onPressed: () => context.push('/clubs/$clubId/members'),
      tooltip: 'Membros',
    ),
  ],
)
```

### 2. Convitar Amigos (Fluxo Único)

Para convidar um amigo específico para um clube (do perfil do amigo):

```dart
// Já está integrado em friend_profile_screen.dart
// O botão "Convidar" abre InviteToClubSheet automaticamente
```

### 3. Adicionar Múltiplos Membros

Para adicionar vários amigos ao mesmo tempo (na tela do clube):

```dart
import 'package:readlog_mobile/features/clubs/presentation/widgets/add_members_button.dart';

AppBar(
  actions: [
    AddMembersButton(
      clubId: clubId,
      clubName: club.name,
    ),
  ],
)
```

Ou manualmente:

```dart
void _showAddMembersDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => InviteMultipleFriendsSheet(
      clubId: clubId,
      clubName: clubName,
    ),
  );
}
```

### 4. Busca Aprimorada na Aba "Amigos"

A aba de busca em `FriendsScreen` agora mostra:
- ✓ Ícone verde: já é amigo
- ⏳ Ícone laranja: convite enviado
- 📨 Ícone de envelope: convite pendente de aceitar
- → Seta: possível adicionar

Nenhuma mudança de integração necessária - funciona automaticamente!

### 5. Perfil Expandido de Amigos

O perfil de amigos agora tem três botões de ação:
- **Adicionar/Amigo**: Gerencia relação de amizade
- **Mensagem**: Placeholder (preparado para integração futura)
- **Convidar**: Abre sheet para selecionar clube

Nenhuma mudança de integração necessária - funciona automaticamente!

### 6. Estados e Feedback

Todas as operações oferecem feedback visual:
- Loading spinners durante operações assíncronas
- SnackBars com mensagens de sucesso/erro
- Diálogos de confirmação para ações destrutivas
- Invalidação automática de cache após operações

### 7. Tratamento de Erros

Todas as operações têm tratamento de erro:

```dart
try {
  await repo.addMemberToClub(clubId, friendId);
  // Sucesso
} catch (e) {
  // Erro é capturado e exibido via SnackBar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erro: $e')),
  );
}
```

### 8. Providers Disponíveis

Novos providers para usar em seus widgets:

```dart
// Amigos para convidar
final _allFriendsProvider = FutureProvider<List<Friend>>((ref) { ... });

// Membros do clube
final _clubMembersProvider = FutureProvider.family<List<ClubMember>, String>((ref, clubId) { ... });

// Status de relacionamento
final _relationshipStatusProvider = FutureProvider.family<String, String>((ref, userId) { ... });

// Meus clubes (para convites)
final _myClubsForInviteProvider = FutureProvider<List<BookClub>>((ref) { ... });
```

### 9. Customização

### Cores

O sistema usa cores do theme Lumen:
- `AppColors.forestGreen` - Ações positivas
- `AppColors.error` - Ações destrutivas
- `AppColors.offWhite` - Fundo
- `AppColors.textMuted` - Texto secundário

### Estilos de Texto

- `AppTextStyles.headlineMedium` - Títulos
- `AppTextStyles.bodyMedium` - Corpo
- `Theme.of(context).textTheme.bodySmall` - Labels

### 10. Checklist de Integração

- [ ] Importar `ClubMembersScreen` nas rotas
- [ ] Adicionar rota `/clubs/{clubId}/members`
- [ ] Importar `AddMembersButton` no AppBar do clube (opcional)
- [ ] Testar fluxo: Perfil → Amigo → Convidar → Clube → Membro
- [ ] Verificar estados de loading e erro
- [ ] Confirmar que membros aparecem corretamente ordenados

### 11. API do Repositório

```dart
// Novo método adicionado a BookClubRepository
Future<void> addMemberToClub(String clubId, String userId)
  // Adiciona usuário com papel 'member'

// Métodos existentes úteis
Future<List<ClubMember>> listMembers(String clubId)
Future<void> promoteMember(String clubId, String userId)
Future<void> demoteMember(String clubId, String userId)
Future<void> removeMember(String clubId, String userId)
```

---

## Fluxos Principais

### Fluxo 1: Adicionar Amigo e Convidar para Clube

1. Usuário abre aba "Buscar" em FriendsScreen
2. Digita nome do amigo
3. Vê resultado com status visual (→ para adicionar)
4. Clica e vai para perfil do amigo
5. Clica no botão "Convidar"
6. Seleciona clube na sheet
7. Amigo é adicionado ao clube como membro

### Fluxo 2: Gerenciar Membros do Clube

1. Na tela de detalhes do clube, clica em "Membros"
2. Vê lista ordenada: owner → admins → mentors → members
3. Clica no menu (...) de cada membro
4. Pode promover, rebaixar ou remover

### Fluxo 3: Convidar Múltiplos Amigos

1. Na tela de membros (ou app bar), clica "+ Adicionar membros"
2. Vê lista de amigos com checkboxes
3. Seleciona vários (a contagem atualiza)
4. Clica "Convidar N"
5. Todos são adicionados em paralelo
