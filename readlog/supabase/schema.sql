-- ============================================================
-- READLOG — Supabase SQL Schema
-- ============================================================

-- EXTENSIONS
create extension if not exists "uuid-ossp";

-- ENUMS
create type book_status as enum ('reading', 'want_to_read', 'read', 'abandoned');
create type note_type   as enum ('observation', 'reflection', 'highlight');
create type goal_type   as enum ('daily_pages', 'daily_minutes', 'yearly_books', 'monthly_pages');
create type goal_period as enum ('daily', 'weekly', 'monthly', 'yearly');

-- HELPER: updated_at trigger function
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ────────────────────────────────────────────────────────────
-- 1. PROFILES
-- ────────────────────────────────────────────────────────────
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique not null,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

alter table profiles enable row level security;

create policy "profiles: owner select" on profiles for select using (auth.uid() = id);
create policy "profiles: owner insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles: owner update" on profiles for update using (auth.uid() = id);
create policy "profiles: owner delete" on profiles for delete using (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- 2. BOOKS
-- ────────────────────────────────────────────────────────────
create table books (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  author      text,
  cover_url   text,
  total_pages integer check (total_pages > 0),
  genre       text,
  publisher   text,
  status      book_status not null default 'want_to_read',
  start_date  date,
  end_date    date,
  rating      smallint check (rating between 1 and 5),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_books_user_id on books(user_id);

create trigger trg_books_updated_at
  before update on books
  for each row execute function set_updated_at();

alter table books enable row level security;

create policy "books: owner select" on books for select using (auth.uid() = user_id);
create policy "books: owner insert" on books for insert with check (auth.uid() = user_id);
create policy "books: owner update" on books for update using (auth.uid() = user_id);
create policy "books: owner delete" on books for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 3. READING SESSIONS
-- ────────────────────────────────────────────────────────────
create table reading_sessions (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  book_id          uuid not null references books(id) on delete cascade,
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  duration_minutes integer check (duration_minutes >= 0),
  start_page       integer check (start_page >= 0),
  end_page         integer check (end_page >= 0),
  pages_read       integer generated always as (
                     case when end_page is not null and start_page is not null
                          then greatest(end_page - start_page, 0)
                          else null end
                   ) stored,
  notes            text,
  created_at       timestamptz not null default now()
);

create index idx_reading_sessions_user_id    on reading_sessions(user_id);
create index idx_reading_sessions_book_id    on reading_sessions(book_id);
create index idx_reading_sessions_started_at on reading_sessions(user_id, started_at);

alter table reading_sessions enable row level security;

create policy "reading_sessions: owner select" on reading_sessions for select using (auth.uid() = user_id);
create policy "reading_sessions: owner insert" on reading_sessions for insert with check (auth.uid() = user_id);
create policy "reading_sessions: owner update" on reading_sessions for update using (auth.uid() = user_id);
create policy "reading_sessions: owner delete" on reading_sessions for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 4. NOTES
-- ────────────────────────────────────────────────────────────
create table notes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  book_id     uuid not null references books(id) on delete cascade,
  type        note_type not null default 'observation',
  content     text not null,
  page_number integer check (page_number >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_notes_user_id on notes(user_id);
create index idx_notes_book_id on notes(book_id);

create trigger trg_notes_updated_at
  before update on notes
  for each row execute function set_updated_at();

alter table notes enable row level security;

create policy "notes: owner select" on notes for select using (auth.uid() = user_id);
create policy "notes: owner insert" on notes for insert with check (auth.uid() = user_id);
create policy "notes: owner update" on notes for update using (auth.uid() = user_id);
create policy "notes: owner delete" on notes for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 5. HIGHLIGHTS
-- ────────────────────────────────────────────────────────────
create table highlights (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  book_id     uuid not null references books(id) on delete cascade,
  text        text not null,
  page_number integer check (page_number >= 0),
  created_at  timestamptz not null default now()
);

create index idx_highlights_user_id on highlights(user_id);
create index idx_highlights_book_id on highlights(book_id);

alter table highlights enable row level security;

create policy "highlights: owner select" on highlights for select using (auth.uid() = user_id);
create policy "highlights: owner insert" on highlights for insert with check (auth.uid() = user_id);
create policy "highlights: owner update" on highlights for update using (auth.uid() = user_id);
create policy "highlights: owner delete" on highlights for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 6. GOALS
-- ────────────────────────────────────────────────────────────
create table goals (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  type         goal_type not null,
  target_value integer not null check (target_value > 0),
  period       goal_period not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_goals_user_id on goals(user_id);

create trigger trg_goals_updated_at
  before update on goals
  for each row execute function set_updated_at();

alter table goals enable row level security;

create policy "goals: owner select" on goals for select using (auth.uid() = user_id);
create policy "goals: owner insert" on goals for insert with check (auth.uid() = user_id);
create policy "goals: owner update" on goals for update using (auth.uid() = user_id);
create policy "goals: owner delete" on goals for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 7. ACHIEVEMENTS
-- ────────────────────────────────────────────────────────────
create table achievements (
  id          uuid primary key default uuid_generate_v4(),
  key         text unique not null,
  name        text not null,
  description text not null,
  icon        text,
  xp_reward   integer not null default 0 check (xp_reward >= 0),
  created_at  timestamptz not null default now()
);

alter table achievements enable row level security;

create policy "achievements: authenticated read"
  on achievements for select
  using (auth.role() = 'authenticated');

-- ────────────────────────────────────────────────────────────
-- 8. USER ACHIEVEMENTS
-- ────────────────────────────────────────────────────────────
create table user_achievements (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references achievements(id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  unique (user_id, achievement_id)
);

create index idx_user_achievements_user_id        on user_achievements(user_id);
create index idx_user_achievements_achievement_id  on user_achievements(achievement_id);

alter table user_achievements enable row level security;

create policy "user_achievements: owner select" on user_achievements for select using (auth.uid() = user_id);
create policy "user_achievements: owner insert" on user_achievements for insert with check (auth.uid() = user_id);
create policy "user_achievements: owner delete" on user_achievements for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 9. WISHLIST
-- ────────────────────────────────────────────────────────────
create table wishlist (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null,
  author     text,
  cover_url  text,
  notes      text,
  acquired   boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_wishlist_user_id on wishlist(user_id);

create trigger trg_wishlist_updated_at
  before update on wishlist
  for each row execute function set_updated_at();

alter table wishlist enable row level security;

create policy "wishlist: owner select" on wishlist for select using (auth.uid() = user_id);
create policy "wishlist: owner insert" on wishlist for insert with check (auth.uid() = user_id);
create policy "wishlist: owner update" on wishlist for update using (auth.uid() = user_id);
create policy "wishlist: owner delete" on wishlist for delete using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- VIEW: daily_stats
-- ────────────────────────────────────────────────────────────
create or replace view daily_stats as
select
  user_id,
  started_at::date       as date,
  sum(duration_minutes)  as total_minutes,
  sum(pages_read)        as total_pages,
  count(*)               as session_count
from reading_sessions
group by user_id, started_at::date;

-- ────────────────────────────────────────────────────────────
-- FUNCTION: calculate_streak(p_user_id uuid)
-- ────────────────────────────────────────────────────────────
create or replace function calculate_streak(p_user_id uuid)
returns integer language plpgsql stable security definer as $$
declare
  v_streak      integer := 0;
  v_check_date  date;
  v_has_session boolean;
begin
  select exists (
    select 1 from reading_sessions
    where user_id = p_user_id and started_at::date = current_date
  ) into v_has_session;

  if v_has_session then
    v_check_date := current_date;
  else
    select exists (
      select 1 from reading_sessions
      where user_id = p_user_id and started_at::date = current_date - 1
    ) into v_has_session;
    if not v_has_session then return 0; end if;
    v_check_date := current_date - 1;
  end if;

  loop
    select exists (
      select 1 from reading_sessions
      where user_id = p_user_id and started_at::date = v_check_date
    ) into v_has_session;
    exit when not v_has_session;
    v_streak     := v_streak + 1;
    v_check_date := v_check_date - 1;
  end loop;

  return v_streak;
end;
$$;

-- ────────────────────────────────────────────────────────────
-- SEED: achievements
-- ────────────────────────────────────────────────────────────
insert into achievements (key, name, description, xp_reward) values
  ('first_session', 'Primeira Sessao',      'Registrou a primeira sessao de leitura.',           50),
  ('first_book',    'Primeiro Livro',       'Marcou o primeiro livro como lido.',                100),
  ('pages_100',     '100 Paginas',          'Leu 100 paginas no total.',                          75),
  ('pages_500',     '500 Paginas',          'Leu 500 paginas no total.',                         150),
  ('pages_1000',    '1000 Paginas',         'Leu 1000 paginas no total.',                        300),
  ('streak_3',      'Sequencia de 3 Dias',  'Leu por 3 dias consecutivos.',                       75),
  ('streak_7',      'Semana Completa',      'Leu por 7 dias consecutivos.',                      150),
  ('streak_30',     'Mes Completo',         'Leu por 30 dias consecutivos.',                     500),
  ('books_5',       '5 Livros Lidos',       'Concluiu 5 livros.',                                200),
  ('books_10',      '10 Livros Lidos',      'Concluiu 10 livros.',                               400),
  ('hours_10',      '10 Horas de Leitura',  'Acumulou 10 horas de leitura registradas.',         100),
  ('hours_100',     '100 Horas de Leitura', 'Acumulou 100 horas de leitura registradas.',        600),
  ('night_owl',     'Leitor Noturno',       'Registrou uma sessao entre meia-noite e 4h.',        50),
  ('speed_reader',  'Leitor Veloz',         'Leu mais de 60 paginas em uma unica sessao.',        75),
  ('annotator',     'Anotador',             'Criou 10 anotacoes ou destaques.',                  100);
