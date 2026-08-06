# Fluxos de Uso - Sistema de Amigos e Clubes

## 🔄 Fluxo 1: Adicionar Amigo e Convidar para Clube

```
┌─────────────────────────────────────────────────────────────┐
│ FriendsScreen - Tab "Buscar"                                │
│                                                              │
│ [SearchBar: "João Silva"]                                  │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ João Silva                          @   → Adicionar   │  │
│ │ "Adorei este livro..."             /  \              │  │
│ └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        ↓ TAP
        ┌───────────────────────────────────────┐
        │ FriendProfileScreen                   │
        │                                       │
        │ [Avatar]                              │
        │ João Silva                            │
        │ @joao.silva                           │
        │                                       │
        │ [Livro Atual] [Estatísticas]         │
        │                                       │
        │ ┌──────────────────────────────────┐ │
        │ │ [♡ Adicionar] [💬 Msg] [📚 Conv]│ │ ← Convite aqui
        │ └──────────────────────────────────┘ │
        └───────────────────────────────────────┘
                        ↓ TAP "Convidar"
            ┌─────────────────────────────┐
            │ InviteToClubSheet           │
            │                             │
            │ Convidar para clube         │
            │                             │
            │ [Clube Ficção]              │ ← Select
            │ [Clube Não-ficção]          │
            │ [Clube Clássicos]           │
            │                             │
            │ [  Convidar  ]              │ ← Action
            └─────────────────────────────┘
                        ↓ TAP
            SnackBar: "Convite enviado!"
                        ↓
        Membro adicionado ao clube
```

---

## 🎯 Fluxo 2: Adicionar Múltiplos Membros

```
┌──────────────────────────────────────────┐
│ ClubDetailScreen                         │
│                                          │
│ AppBar:                                  │
│ [← Clube Ficção] [⋯] [👥 +]           │ ← Add Members
│                                          │
└──────────────────────────────────────────┘
                   ↓ TAP [👥 +]
    ┌────────────────────────────────────┐
    │ InviteMultipleFriendsSheet         │
    │                                    │
    │ Convidar amigos                    │
    │                                    │
    │ [🔍 Buscar amigos...]              │
    │                                    │
    │ ☐ Ana Silva                        │
    │   "Leitora apaixonada"             │
    │                                    │
    │ ☑ Bruno Costa                      │ ← Selected
    │   "Fã de ficção científica"        │
    │                                    │
    │ ☐ Carlos Mendes                    │
    │   "Clássicos são vida"             │
    │                                    │
    │ [  Convidar 1  ]                   │ ← Dynamic count
    └────────────────────────────────────┘
              ↓ TAP Checkbox
    Count: "Convidar 1" → "Convidar 2"
              ↓ TAP [Convidar 2]
    SnackBar: "2 convites enviados!"
```

---

## 👥 Fluxo 3: Gerenciar Membros

```
┌─────────────────────────────────────┐
│ ClubDetailScreen                    │
│                                     │
│ [← Clube Ficção] [👥 15] [⋯]      │
│                                     │
│ ┌─────────────────────────────────┐│
│ │ Ver Membros ┌─────────────────┐││
│ │             │ 📱 OWNER        │││
│ │             │ 🛡️ ADMIN (3)    │││
│ │             │ 🎓 MENTOR (2)   │││
│ │             │ 👤 MEMBER (9)   │││
│ │             └─────────────────┘││
│ └─────────────────────────────────┘│
└─────────────────────────────────────┘
         ↓ Tap "Ver Membros"
    ┌────────────────────────────┐
    │ ClubMembersScreen          │
    │                            │
    │ ┌──────────────────────┐  │
    │ │ 👤 João (OWNER)      │  │ ← Owner
    │ │    Owner desde 2023  │  │
    │ └──────────────────────┘  │
    │                            │
    │ ┌──────────────────────┐  │
    │ │ 👤 Maria (ADMIN) [⋮] │  │ ← Admin
    │ │    Admin desde 2024  │  │
    │ └──────────────────────┘  │
    │          ↓ TAP [⋮]
    │    ┌──────────────────┐
    │    │ 👤 Ver perfil    │
    │    │ 🛡️ Rebaixar      │ ← Options
    │    │ ❌ Remover       │
    │    └──────────────────┘
    │
    │ ┌──────────────────────┐  │
    │ │ 👤 Carlos (MEMBER)   │  │ ← Member
    │ │    Member 5h ago [⋮] │  │
    │ └──────────────────────┘  │
    │          ↓ TAP [⋮]
    │    ┌──────────────────┐
    │    │ 👤 Ver perfil    │
    │    │ 🛡️ Promover      │ ← Options
    │    │ ❌ Remover       │
    │    └──────────────────┘
    └────────────────────────────┘
```

---

## 📊 Componentes do Sistema

### InviteToClubSheet
```dart
┌────────────────────────────────────┐
│ Handle (drag indicator)            │
│ "Convidar para clube"              │
│ "Escolha um clube para convidar..." │
├────────────────────────────────────┤
│ [Clube Ficção]        ← selectable │
│ [Clube Não-ficção]    ← selectable │
│ [Clube Clássicos]     ← selectable │
├────────────────────────────────────┤
│ [  Convidar Amigo  ]               │
└────────────────────────────────────┘
```

### InviteMultipleFriendsSheet
```dart
┌────────────────────────────────────┐
│ Handle                             │
│ "Convidar amigos"                  │
│ "Selecione amigos para convidar..." │
├────────────────────────────────────┤
│ [🔍 Buscar amigos...] [✕]         │
├────────────────────────────────────┤
│ ☐ 👤 Ana Silva                     │
│    Bio truncada...                 │
│ ☑ 👤 Bruno Costa   ← selected      │
│    Bio truncada...                 │
│ ☐ 👤 Carlos Mendes                 │
│    Bio truncada...                 │
├────────────────────────────────────┤
│ [  Convidar 1  ]                   │
└────────────────────────────────────┘
```

### ClubMembersScreen
```dart
┌────────────────────────────────────┐
│ AppBar                             │
│ [←] Membros                        │
├────────────────────────────────────┤
│ 👤 João Silva        OWNER  [👥]  │
│ "Owner desde 2023"                 │
├────────────────────────────────────┤
│ 👤 Maria Costa       ADMIN  [⋮]   │
│ "Admin desde 2024"                 │
├────────────────────────────────────┤
│ 👤 Pedro Oliveira    MEMBER [⋮]   │
│ "Joined 2h ago"                    │
├────────────────────────────────────┤
│ [⟳] Pull to refresh                │
└────────────────────────────────────┘
```

---

## 🔄 Estados Visuais na Busca

```
Relacionamento: None
├─ Status: "Possível adicionar"
└─ Ícone: → (seta cinza)

Relacionamento: Pending Sent
├─ Status: "Convite enviado"
└─ Ícone: ⏳ (ampulheta laranja)

Relacionamento: Pending Received
├─ Status: "Pendente"
└─ Ícone: 📨 (envelope azul)

Relacionamento: Friend
├─ Status: "Já é amigo"
└─ Ícone: ✓ (checkmark verde)
```

---

## ⚡ Estados de Carregamento

```
Durante operação:
├─ Spinner circular no centro
├─ Botões desabilitados
├─ Input desabilitado
└─ Contagem pausada

Após sucesso:
├─ SnackBar: "Convite enviado!"
├─ Pop sheet (Navigator.pop)
├─ Invalidar cache
└─ Retornar para tela anterior

Após erro:
├─ SnackBar: "Erro: mensagem"
├─ Sheet permanece aberta
└─ Usuário pode tentar novamente
```

---

## 🎨 Pré-requisitos Visuais

Todos os componentes usam:
- **Design System:** Lumen
- **Cores:** AppColors (forestGreen, error, offWhite, textMuted)
- **Tipografia:** AppTextStyles (headlineMedium, bodyMedium, labelMedium)
- **Espaçamento:** Padrão Material Design
- **Ícones:** Material Icons
- **Animações:** Suave (sem excesso)

---

## 🧪 Checklist de Testes

- [ ] Adicionar amigo novo → mostrar ícone de adicionar
- [ ] Enviar convite → mostrar ícone de pendente
- [ ] Aceitar convite → mostrar ícone de amigo
- [ ] Convidar para clube → amigo aparece em ClubMembersScreen
- [ ] Promover membro → papel atualizado
- [ ] Remover membro → removido da lista após confirmação
- [ ] Buscar múltiplos → selection count atualizado
- [ ] Pull-to-refresh → lista recarrega
- [ ] Offline → mostrar erro gracioso

---

Este documento visualiza todos os fluxos principais do sistema.
Para detalhes técnicos, ver `IMPLEMENTATION_SUMMARY.md`
Para integração, ver `INTEGRATION_GUIDE.md`
