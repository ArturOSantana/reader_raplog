# Lumen Monorepo

Monorepo Turborepo com três aplicações Next.js independentes e packages compartilhados.

## Estrutura

```
lumen/
├── apps/
│   ├── marketing/      → lumen.app          (Marketing, SEO, blog, páginas públicas)
│   ├── web/            → app.lumen.app      (Web Platform autenticado)
│   └── admin/          → admin.lumen.app    (Admin Console — somente time Lumen)
├── packages/
│   ├── types/          → @lumen/types       (Tipos TypeScript compartilhados)
│   ├── ui/             → @lumen/ui          (Utilitários: cn, formatMinutes, etc.)
│   └── supabase/       → @lumen/supabase    (Clientes Supabase SSR + browser)
├── turbo.json
└── package.json
```

## Premissa de design

| App         | Propósito                                          | Quem acessa             |
|-------------|---------------------------------------------------|-------------------------|
| marketing   | Converter visitantes, SEO, blog                   | Público                 |
| web         | Produtividade desktop, biblioteca, clubes          | Usuários autenticados   |
| admin       | Operação do negócio, moderação, analytics          | Somente time Lumen      |

O Flutter Mobile é responsável pelo hábito de leitura e check-ins diários.
O Web Platform é uma **experiência desktop diferente** — não uma cópia do app.
O Admin Console é **completamente separado** do Web Platform por design.

## Setup

```bash
# Instalar dependências (workspace npm)
npm install

# Rodar todas as apps em dev
npm run dev

# Rodar apenas uma app
npm run dev:marketing     # http://localhost:3000
npm run dev:web           # http://localhost:3001
npm run dev:admin         # http://localhost:3002
```

### Variáveis de ambiente

Cada app tem seu próprio `.env.example`. Copie e preencha:

```bash
cp apps/marketing/.env.example apps/marketing/.env.local
cp apps/web/.env.example       apps/web/.env.local
cp apps/admin/.env.example     apps/admin/.env.local
```

## Scripts

```bash
npm run build       # Build todos os apps
npm run lint        # Lint todos os apps
npm run typecheck   # TypeScript check em tudo
```

## Segurança

- `apps/admin` nunca é exposto junto com `apps/web`.
- O middleware de `apps/admin` verifica role via JWT antes de qualquer render.
- Roles aceitas no Admin: `super_admin`, `admin`, `support`, `moderator`, `analyst`.
- `.env.local` está no `.gitignore` — nunca commite segredos.
- TLS 1.3 via Supabase para todos os dados em trânsito.

## Backend compartilhado

Todas as apps usam o mesmo projeto Supabase:
- PostgreSQL
- Auth (OAuth Google + magic link)
- Storage
- Realtime
- Edge Functions
