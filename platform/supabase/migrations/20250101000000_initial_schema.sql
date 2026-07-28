-- ============================================================
-- Lumen Platform — Migration 0001: Schema inicial completo
-- Spec §3: Banco de dados PostgreSQL (Supabase)
-- Spec §4: RLS — toda permissão verificada no banco
-- Spec §21: Segurança, TLS 1.3, sem secrets hardcoded
-- ============================================================

-- Habilita extensões necessárias
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";   -- busca textual por trigram
create extension if not exists "unaccent";  -- busca sem acentos

-- ============================================================
-- ENUM TYPES
-- ============================================================

create type user_status     as enum ('active', 'suspended', 'banned', 'pending');
create type book_status     as enum ('reading', 'want_to_read', 'finished', 'abandoned', 'did_not_finish');
create type club_status     as enum ('active', 'on_vacation', 'closed', 'archived');
create type club_visibility as enum ('public', 'private', 'invite_only');
create type club_member_role as enum ('owner', 'admin', 'moderator', 'member');
create type club_category   as enum (
  'general', 'fiction', 'nonfiction', 'fantasy', 'scifi',
  'romance', 'mystery', 'biography', 'history', 'selfhelp',
  'children', 'classics'
);
create type privacy_level   as enum ('public', 'friends', 'private');
create type privacy_club    as enum ('public', 'friends', 'club', 'private');
create type report_status   as enum ('open', 'reviewing', 'resolved', 'dismissed');
create type report_type     as enum ('spam', 'spoiler', 'offensive', 'harassment', 'other');
create type sub_status      as enum ('trialing', 'active', 'past_due', 'canceled', 'expired');
create type sub_plan        as enum ('free', 'premium_monthly', 'premium_annual');
create type sub_channel     as enum ('stripe', 'apple', 'google', 'manual');
create type invite_type     as enum ('early_access', 'beta', 'gift');
create type invite_status   as enum ('pending', 'used', 'expired', 'revoked');
create type lgpd_type       as enum ('deletion', 'export');
create type lgpd_status     as enum ('pending', 'processing', 'completed', 'failed');
create type note_type       as enum ('observation', 'reflection', 'highlight');
create type list_visibility as enum ('public', 'friends', 'private');

-- ============================================================
-- PROFILES
-- Extensão da tabela auth.users do Supabase
-- ============================================================

create table profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  username        text unique not null,
  full_name       text,
  bio             text,
  avatar_url      text,
  email           text,                    -- cache do auth.users
  role            text not null default 'user',
  status          user_status not null default 'active',

  -- Privacidade (spec §9) — padrão privado, exceto reviews e perfil
  privacy_profile  privacy_level not null default 'public',
  privacy_library  privacy_level not null default 'private',
  privacy_reviews  privacy_level not null default 'public',
  privacy_stats    privacy_level not null default 'private',
  privacy_lists    privacy_level not null default 'private',
  privacy_favorites privacy_level not null default 'private',
  privacy_followers text not null default 'visible', -- 'visible' | 'hidden'

  -- Streak & gamificação
  current_streak  integer not null default 0,
  longest_streak  integer not null default 0,
  last_read_at    timestamptz,
  xp_total        integer not null default 0,

  -- LGPD
  data_export_requested_at  timestamptz,
  deletion_requested_at     timestamptz,

  -- MFA (spec §7)
  mfa_enabled     boolean not null default false,

  -- Shadow ban (spec §16)
  shadow_banned   boolean not null default false,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint username_format check (username ~ '^[a-z0-9_]{3,30}$'),
  constraint bio_length      check (char_length(bio) <= 500)
);

-- Índices para busca de usuários (Admin/Support)
create index idx_profiles_username   on profiles using btree(username);
create index idx_profiles_email      on profiles using btree(email);
create index idx_profiles_role       on profiles using btree(role);
create index idx_profiles_status     on profiles using btree(status);
create index idx_profiles_created_at on profiles using btree(created_at desc);
-- Busca textual por nome/username
create index idx_profiles_fts on profiles using gin(
  to_tsvector('portuguese', coalesce(username,'') || ' ' || coalesce(full_name,''))
);

-- ============================================================
-- FOLLOWS (social graph)
-- ============================================================

create table follows (
  follower_id uuid not null references profiles(id) on delete cascade,
  following_id uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id != following_id)
);

create index idx_follows_follower  on follows(follower_id);
create index idx_follows_following on follows(following_id);

-- ============================================================
-- BOOK CATALOG (catálogo público de livros)
-- ============================================================

create table book_catalog (
  id              uuid primary key default gen_random_uuid(),
  slug            text unique not null,
  google_books_id text unique,
  title           text not null,
  author          text not null,
  author_id       uuid,  -- FK para authors (opcional, para páginas de autor)
  isbn            text,
  publisher       text,
  published_year  integer,
  page_count      integer,
  description     text,
  cover_url       text,
  language        text default 'pt-BR',
  categories      text[],
  -- Aggregados desnormalizados (atualizados por trigger/cron)
  reader_count    integer not null default 0,
  avg_rating      numeric(3,2),
  review_count    integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_book_catalog_slug      on book_catalog(slug);
create index idx_book_catalog_google_id on book_catalog(google_books_id);
create index idx_book_catalog_author    on book_catalog using btree(author);
create index idx_book_catalog_fts on book_catalog using gin(
  to_tsvector('portuguese', coalesce(title,'') || ' ' || coalesce(author,'') || ' ' || coalesce(description,''))
);

-- ============================================================
-- AUTHORS
-- ============================================================

create table authors (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  name         text not null,
  bio          text,
  photo_url    text,
  nationality  text,
  born_year    integer,
  website_url  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table book_catalog
  add constraint fk_book_catalog_author
  foreign key (author_id) references authors(id) on delete set null;

create index idx_authors_slug on authors(slug);

-- ============================================================
-- BOOKS (biblioteca pessoal — por usuário)
-- ============================================================

create table books (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  book_catalog_id uuid references book_catalog(id) on delete set null,
  -- Dados locais (podem divergir do catálogo)
  title           text not null,
  author          text,
  cover_url       text,
  isbn            text,
  publisher       text,
  published_year  integer,
  page_count      integer,
  status          book_status not null default 'want_to_read',
  current_page    integer not null default 0,
  rating          integer check (rating between 1 and 5),
  review          text,
  review_visibility privacy_level not null default 'public',
  started_at      timestamptz,
  finished_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_books_user_id    on books(user_id);
create index idx_books_status     on books(user_id, status);
create index idx_books_catalog_id on books(book_catalog_id);
create index idx_books_finished   on books(user_id, finished_at desc nulls last);

-- ============================================================
-- READING SESSIONS (spec §1: Core Loop)
-- ============================================================

create table reading_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  book_id          uuid not null references books(id) on delete cascade,
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  duration_minutes integer,
  start_page       integer,
  end_page         integer,
  pages_read       integer generated always as (
    case when end_page is not null and start_page is not null
    then greatest(end_page - start_page, 0)
    else null end
  ) stored,
  notes            text,
  created_at       timestamptz not null default now()
);

create index idx_sessions_user_id    on reading_sessions(user_id);
create index idx_sessions_book_id    on reading_sessions(book_id);
create index idx_sessions_started_at on reading_sessions(user_id, started_at desc);

-- ============================================================
-- NOTES & HIGHLIGHTS (spec §9: nunca públicos)
-- ============================================================

create table notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  book_id     uuid not null references books(id) on delete cascade,
  type        note_type not null default 'observation',
  content     text not null,
  page_number integer,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table highlights (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  book_id     uuid not null references books(id) on delete cascade,
  text        text not null,
  page_number integer,
  color       text default 'yellow',
  created_at  timestamptz not null default now()
);

create index idx_notes_user_book      on notes(user_id, book_id);
create index idx_highlights_user_book on highlights(user_id, book_id);

-- ============================================================
-- GOALS (metas de leitura)
-- ============================================================

create table goals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  type         text not null,   -- 'daily_pages' | 'daily_minutes' | 'yearly_books' etc.
  target_value integer not null,
  period       text not null,   -- 'daily' | 'weekly' | 'monthly' | 'yearly'
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_goals_user_id on goals(user_id);

-- ============================================================
-- REVIEWS (públicas, vinculadas ao catálogo)
-- ============================================================

create table reviews (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  book_catalog_id uuid not null references book_catalog(id) on delete cascade,
  book_id         uuid references books(id) on delete set null,  -- link para biblioteca pessoal
  rating          integer not null check (rating between 1 and 5),
  content         text,
  visibility      privacy_level not null default 'public',
  contains_spoiler boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, book_catalog_id)
);

create index idx_reviews_book_catalog on reviews(book_catalog_id, visibility);
create index idx_reviews_user_id      on reviews(user_id);
create index idx_reviews_rating       on reviews(book_catalog_id, rating);

-- ============================================================
-- BOOK CLUBS (spec §3, §15)
-- ============================================================

create table book_clubs (
  id                     uuid primary key default gen_random_uuid(),
  slug                   text unique not null,
  owner_id               uuid not null references profiles(id),
  name                   text not null,
  description            text,
  cover_url              text,
  category               club_category not null default 'general',
  visibility             club_visibility not null default 'public',
  status                 club_status not null default 'active',
  invite_code            text unique,
  max_members            integer default 100,
  -- Livro atual desnormalizado (performance de leitura pública)
  current_book_id        uuid,
  current_book_title     text,
  current_book_author    text,
  current_book_cover_url text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index idx_clubs_slug       on book_clubs(slug);
create index idx_clubs_status     on book_clubs(status);
create index idx_clubs_visibility on book_clubs(visibility);
create index idx_clubs_owner_id   on book_clubs(owner_id);
create index idx_clubs_fts on book_clubs using gin(
  to_tsvector('portuguese', coalesce(name,'') || ' ' || coalesce(description,''))
);

-- ============================================================
-- CLUB MEMBERS
-- ============================================================

create table book_club_members (
  club_id    uuid not null references book_clubs(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  role       club_member_role not null default 'member',
  joined_at  timestamptz not null default now(),
  primary key (club_id, user_id)
);

create index idx_club_members_user_id on book_club_members(user_id);
create index idx_club_members_club_id on book_club_members(club_id);

-- ============================================================
-- CLUB CHECKINS (progresso no livro do clube)
-- ============================================================

create table book_club_checkins (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references book_clubs(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  pages_read  integer,
  note        text,
  created_at  timestamptz not null default now()
);

create index idx_checkins_club_id on book_club_checkins(club_id, created_at desc);
create index idx_checkins_user_id on book_club_checkins(user_id);

-- ============================================================
-- BOOK LISTS (listas curadas pelo usuário)
-- ============================================================

create table book_lists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  title       text not null,
  description text,
  cover_url   text,
  visibility  list_visibility not null default 'private',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table book_list_items (
  id          uuid primary key default gen_random_uuid(),
  list_id     uuid not null references book_lists(id) on delete cascade,
  book_catalog_id uuid not null references book_catalog(id) on delete cascade,
  position    integer not null default 0,
  note        text,
  added_at    timestamptz not null default now(),
  unique (list_id, book_catalog_id)
);

create index idx_book_lists_user_id    on book_lists(user_id);
create index idx_book_lists_visibility on book_lists(visibility);
create index idx_book_list_items_list  on book_list_items(list_id, position);

-- ============================================================
-- ACHIEVEMENTS (spec §22 V1)
-- ============================================================

create table achievements (
  id          uuid primary key default gen_random_uuid(),
  key         text unique not null,
  name        text not null,
  description text not null,
  icon        text,
  xp_reward   integer not null default 0,
  created_at  timestamptz not null default now()
);

create table user_achievements (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references profiles(id) on delete cascade,
  achievement_id uuid not null references achievements(id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  unique (user_id, achievement_id)
);

create index idx_user_achievements_user on user_achievements(user_id);

-- ============================================================
-- SUBSCRIPTIONS (spec §17: fonte única de verdade)
-- ============================================================

create table subscriptions (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references profiles(id) on delete cascade,
  plan                 sub_plan not null default 'free',
  status               sub_status not null default 'active',
  channel              sub_channel not null default 'stripe',
  -- IDs externos
  stripe_subscription_id     text unique,
  stripe_customer_id         text,
  apple_original_transaction_id text unique,
  google_purchase_token      text unique,
  -- Datas
  trial_start_at       timestamptz,
  trial_end_at         timestamptz,
  current_period_start timestamptz,
  current_period_end   timestamptz,
  canceled_at          timestamptz,
  grace_period_end_at  timestamptz,
  -- Metadados
  price_amount         integer,   -- centavos
  currency             text default 'BRL',
  coupon_code          text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index idx_subscriptions_user_id on subscriptions(user_id);
create index idx_subscriptions_status  on subscriptions(status);
create index idx_subscriptions_stripe  on subscriptions(stripe_subscription_id);

-- ============================================================
-- REPORTS (denúncias — spec §15, §16)
-- ============================================================

create table reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references profiles(id) on delete cascade,
  target_user_id uuid references profiles(id) on delete set null,
  target_type  text not null,   -- 'review' | 'note' | 'club' | 'user' | 'comment'
  target_id    uuid not null,
  type         report_type not null,
  reason       text,
  status       report_status not null default 'open',
  resolved_by  uuid references profiles(id),
  resolution   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_reports_status     on reports(status, created_at desc);
create index idx_reports_reporter   on reports(reporter_id);
create index idx_reports_target     on reports(target_type, target_id);

-- ============================================================
-- AUDIT LOGS (spec §10: imutável, 2 anos de retenção)
-- ============================================================

create table audit_logs (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid references profiles(id) on delete set null,
  target_id  uuid,
  action     text not null,      -- 'user.login', 'admin.user_suspended', etc.
  metadata   jsonb default '{}',
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now()
);

-- Nunca permitir UPDATE ou DELETE em audit_logs (imutabilidade)
create rule audit_logs_no_update as on update to audit_logs do instead nothing;
create rule audit_logs_no_delete as on delete to audit_logs do instead nothing;

create index idx_audit_logs_actor_id  on audit_logs(actor_id);
create index idx_audit_logs_action    on audit_logs(action);
create index idx_audit_logs_created   on audit_logs(created_at desc);
create index idx_audit_logs_target    on audit_logs(target_id);

-- ============================================================
-- FEATURE FLAGS (spec §19)
-- ============================================================

create table feature_flags (
  id               uuid primary key default gen_random_uuid(),
  key              text unique not null,
  description      text not null default '',
  enabled          boolean not null default false,
  rollout_percent  integer not null default 0 check (rollout_percent between 0 and 100),
  target_roles     text[] default '{}',
  target_user_ids  uuid[] default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index idx_feature_flags_key     on feature_flags(key);
create index idx_feature_flags_enabled on feature_flags(enabled);

-- ============================================================
-- INVITES (spec §15: Early Access, beta fechado)
-- ============================================================

create table invites (
  id           uuid primary key default gen_random_uuid(),
  code         text unique not null,
  type         invite_type not null default 'early_access',
  status       invite_status not null default 'pending',
  email        text,                -- destinatário pré-definido (opcional)
  used_by      uuid references profiles(id) on delete set null,
  used_at      timestamptz,
  expires_at   timestamptz,
  created_by   uuid references profiles(id) on delete set null,
  max_uses     integer not null default 1,
  use_count    integer not null default 0,
  notes        text,
  created_at   timestamptz not null default now()
);

create index idx_invites_code   on invites(code);
create index idx_invites_status on invites(status);
create index idx_invites_email  on invites(email);

-- ============================================================
-- LGPD REQUESTS (spec §11)
-- ============================================================

create table lgpd_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete set null,
  type         lgpd_type not null,
  status       lgpd_status not null default 'pending',
  requested_at timestamptz not null default now(),
  deadline_at  timestamptz not null generated always as (
    case type
    when 'export'   then requested_at + interval '15 days'
    when 'deletion' then requested_at + interval '30 days'
    end
  ) stored,
  processed_at timestamptz,
  processed_by uuid references profiles(id) on delete set null,
  notes        text,
  export_url   text  -- URL assinada para download (expiração em 24h)
);

create index idx_lgpd_status  on lgpd_requests(status);
create index idx_lgpd_user_id on lgpd_requests(user_id);

-- ============================================================
-- PUSH NOTIFICATION TOKENS
-- ============================================================

create table push_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android')),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index idx_push_tokens_user_id on push_tokens(user_id);

-- ============================================================
-- UPDATED_AT TRIGGER (automatiza updated_at)
-- ============================================================

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

create trigger trg_books_updated_at
  before update on books
  for each row execute function set_updated_at();

create trigger trg_notes_updated_at
  before update on notes
  for each row execute function set_updated_at();

create trigger trg_reviews_updated_at
  before update on reviews
  for each row execute function set_updated_at();

create trigger trg_clubs_updated_at
  before update on book_clubs
  for each row execute function set_updated_at();

create trigger trg_lists_updated_at
  before update on book_lists
  for each row execute function set_updated_at();

create trigger trg_subscriptions_updated_at
  before update on subscriptions
  for each row execute function set_updated_at();

create trigger trg_goals_updated_at
  before update on goals
  for each row execute function set_updated_at();

create trigger trg_feature_flags_updated_at
  before update on feature_flags
  for each row execute function set_updated_at();

create trigger trg_reports_updated_at
  before update on reports
  for each row execute function set_updated_at();

create trigger trg_book_catalog_updated_at
  before update on book_catalog
  for each row execute function set_updated_at();

create trigger trg_authors_updated_at
  before update on authors
  for each row execute function set_updated_at();

-- ============================================================
-- AUTO-PROFILE após signup (sync com auth.users)
-- ============================================================

create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, full_name, email, avatar_url)
  values (
    new.id,
    -- username: parte do email antes do @ + sufixo aleatório para evitar colisão
    lower(regexp_replace(split_part(new.email, '@', 1), '[^a-z0-9_]', '', 'g'))
      || '_' || left(replace(gen_random_uuid()::text, '-', ''), 6),
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
