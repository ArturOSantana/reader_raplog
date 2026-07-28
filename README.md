# Lumen — Monorepo

Repositório único com todo o código da plataforma Lumen.

```
lumen/                     ← raiz do repo
├── mobile/                ← Flutter app (Android + iOS)
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── supabase/          ← migrations + edge functions do mobile
├── platform/              ← Turborepo (Next.js)
│   ├── apps/
│   │   ├── marketing/     ← lumen.app  (Next.js 15, porta 3000)
│   │   ├── web/           ← app.lumen.app (Next.js 15, porta 3001)
│   │   └── admin/         ← admin.lumen.app (Next.js 15, porta 3002)
│   ├── packages/
│   │   ├── ui/            ← componentes compartilhados
│   │   ├── types/         ← tipos TypeScript compartilhados
│   │   └── supabase/      ← cliente Supabase SSR/browser compartilhado
│   └── supabase/          ← migrations + edge functions da platform
└── .github/workflows/
    ├── beta.yml           ← CI Android → Firebase App Distribution
    └── deploy-web.yml     ← CI Flutter Web → Vercel  (em breve)
```

## Setup rápido

### Mobile (Flutter)
```bash
cd mobile
cp .env.example .env   # preencha com suas chaves
flutter pub get
flutter run
```

### Platform (Next.js Turborepo)
```bash
cd platform
cp apps/web/.env.example apps/web/.env.local
cp apps/admin/.env.example apps/admin/.env.local
cp apps/marketing/.env.example apps/marketing/.env.local
# preencha os valores em cada .env.local
npm install
npm run dev            # inicia os 3 apps em paralelo
```

## CI/CD

| Workflow | Trigger | Resultado |
|---|---|---|
| `beta.yml` | push `main` — mudança em `mobile/**` | APK Android → Firebase App Distribution |
| `deploy-web.yml` | push `main` — mudança em `platform/**` | Next.js apps → Vercel |
