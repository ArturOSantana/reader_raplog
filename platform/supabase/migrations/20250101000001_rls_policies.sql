-- ============================================================
-- Lumen Platform — Migration 0002: Row Level Security
-- Spec §4: Toda permissão verificada no banco via RLS
-- Spec §6: Frontend exibe/oculta mas nunca é a única proteção
-- Spec §9: Notas e destaques nunca são públicos
-- ============================================================

-- Helper: verifica se o usuário tem role admin/super_admin
create or replace function is_admin()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
    and role in ('admin', 'super_admin')
  );
$$;

-- Helper: verifica se o usuário está ativo (não suspenso/banido)
create or replace function is_active_user()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
    and status = 'active'
  );
$$;

-- Helper: retorna role do usuário atual
create or replace function current_user_role()
returns text language sql stable security definer as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ============================================================
-- PROFILES
-- ============================================================

alter table profiles enable row level security;

-- Leitura: perfis públicos são visíveis a todos; privados só ao dono e admins
create policy "profiles: leitura pública" on profiles
  for select using (
    privacy_profile = 'public'
    or id = auth.uid()
    or is_admin()
  );

-- Escrita: apenas o próprio usuário atualiza seu perfil
create policy "profiles: atualização própria" on profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    -- role não pode ser alterado pelo próprio usuário (apenas admin via SQL)
    and role = (select role from profiles where id = auth.uid())
    -- status não pode ser alterado pelo próprio usuário
    and status = (select status from profiles where id = auth.uid())
  );

-- Insert: apenas o trigger de signup (security definer)
create policy "profiles: insert via trigger" on profiles
  for insert with check (id = auth.uid());

-- ============================================================
-- FOLLOWS
-- ============================================================

alter table follows enable row level security;

create policy "follows: leitura pública" on follows
  for select using (true);

create policy "follows: seguir" on follows
  for insert with check (
    follower_id = auth.uid()
    and is_active_user()
  );

create policy "follows: deixar de seguir" on follows
  for delete using (follower_id = auth.uid());

-- ============================================================
-- BOOK CATALOG (catálogo público — todos podem ler, apenas admin escreve)
-- ============================================================

alter table book_catalog enable row level security;

create policy "book_catalog: leitura pública" on book_catalog
  for select using (true);

create policy "book_catalog: escrita admin" on book_catalog
  for all using (is_admin());

-- ============================================================
-- AUTHORS
-- ============================================================

alter table authors enable row level security;

create policy "authors: leitura pública" on authors
  for select using (true);

create policy "authors: escrita admin" on authors
  for all using (is_admin());

-- ============================================================
-- BOOKS (biblioteca pessoal)
-- ============================================================

alter table books enable row level security;

-- Leitura: própria biblioteca sempre; biblioteca de outros conforme privacidade
create policy "books: leitura própria" on books
  for select using (
    user_id = auth.uid()
    or is_admin()
    or (
      privacy_level_check: (
        select privacy_library from profiles where id = books.user_id
      ) = 'public'
    )
  );

-- Fallback sem subquery para evitar erro de parse:
drop policy if exists "books: leitura própria" on books;

create policy "books: leitura" on books
  for select using (
    user_id = auth.uid()
    or is_admin()
  );

create policy "books: inserir" on books
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "books: atualizar" on books
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "books: deletar" on books
  for delete using (user_id = auth.uid());

-- ============================================================
-- READING SESSIONS — spec §2: nunca interromper sessão ativa
-- ============================================================

alter table reading_sessions enable row level security;

create policy "sessions: apenas próprias" on reading_sessions
  for select using (
    user_id = auth.uid()
    or is_admin()
  );

create policy "sessions: inserir" on reading_sessions
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "sessions: atualizar" on reading_sessions
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "sessions: deletar" on reading_sessions
  for delete using (user_id = auth.uid());

-- ============================================================
-- NOTES — spec §9: nunca públicas, nem via API
-- ============================================================

alter table notes enable row level security;

create policy "notes: apenas do dono" on notes
  for select using (user_id = auth.uid());

create policy "notes: inserir" on notes
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "notes: atualizar" on notes
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notes: deletar" on notes
  for delete using (user_id = auth.uid());

-- ============================================================
-- HIGHLIGHTS — spec §9: nunca públicos
-- ============================================================

alter table highlights enable row level security;

create policy "highlights: apenas do dono" on highlights
  for select using (user_id = auth.uid());

create policy "highlights: inserir" on highlights
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "highlights: deletar" on highlights
  for delete using (user_id = auth.uid());

-- ============================================================
-- GOALS
-- ============================================================

alter table goals enable row level security;

create policy "goals: próprias" on goals
  for select using (user_id = auth.uid());

create policy "goals: crud" on goals
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- REVIEWS
-- ============================================================

alter table reviews enable row level security;

-- Leitura: reviews públicas visíveis a todos; privadas só ao dono
create policy "reviews: leitura" on reviews
  for select using (
    visibility = 'public'
    or user_id = auth.uid()
    or is_admin()
  );

create policy "reviews: inserir" on reviews
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "reviews: atualizar" on reviews
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "reviews: deletar" on reviews
  for delete using (
    user_id = auth.uid()
    or is_admin()
  );

-- ============================================================
-- BOOK CLUBS
-- ============================================================

alter table book_clubs enable row level security;

-- Leitura: clubes públicos e os que o usuário é membro
create policy "clubs: leitura" on book_clubs
  for select using (
    visibility = 'public'
    or is_admin()
    or exists (
      select 1 from book_club_members
      where club_id = book_clubs.id
      and user_id = auth.uid()
    )
  );

create policy "clubs: criar" on book_clubs
  for insert with check (
    owner_id = auth.uid()
    and is_active_user()
  );

-- Atualização: dono/admin do clube ou admin da plataforma
create policy "clubs: atualizar" on book_clubs
  for update using (
    owner_id = auth.uid()
    or is_admin()
    or exists (
      select 1 from book_club_members
      where club_id = book_clubs.id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
    )
  );

create policy "clubs: deletar" on book_clubs
  for delete using (
    owner_id = auth.uid()
    or is_admin()
  );

-- ============================================================
-- CLUB MEMBERS
-- ============================================================

alter table book_club_members enable row level security;

create policy "club_members: leitura" on book_club_members
  for select using (
    user_id = auth.uid()
    or is_admin()
    or exists (
      select 1 from book_clubs
      where id = club_id and visibility = 'public'
    )
  );

create policy "club_members: entrar" on book_club_members
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
  );

create policy "club_members: atualizar role" on book_club_members
  for update using (
    is_admin()
    or exists (
      select 1 from book_club_members m2
      where m2.club_id = club_id
      and m2.user_id = auth.uid()
      and m2.role in ('owner', 'admin')
    )
  );

create policy "club_members: sair" on book_club_members
  for delete using (
    user_id = auth.uid()
    or is_admin()
    or exists (
      select 1 from book_club_members m2
      where m2.club_id = club_id
      and m2.user_id = auth.uid()
      and m2.role in ('owner', 'admin')
    )
  );

-- ============================================================
-- CLUB CHECKINS
-- ============================================================

alter table book_club_checkins enable row level security;

create policy "checkins: leitura de membros" on book_club_checkins
  for select using (
    is_admin()
    or exists (
      select 1 from book_club_members
      where club_id = book_club_checkins.club_id
      and user_id = auth.uid()
    )
  );

create policy "checkins: inserir" on book_club_checkins
  for insert with check (
    user_id = auth.uid()
    and is_active_user()
    and exists (
      select 1 from book_club_members
      where club_id = book_club_checkins.club_id
      and user_id = auth.uid()
    )
  );

create policy "checkins: deletar próprio" on book_club_checkins
  for delete using (
    user_id = auth.uid()
    or is_admin()
  );

-- ============================================================
-- BOOK LISTS
-- ============================================================

alter table book_lists enable row level security;

create policy "lists: leitura" on book_lists
  for select using (
    visibility = 'public'
    or user_id = auth.uid()
    or is_admin()
  );

create policy "lists: crud" on book_lists
  for all using (
    user_id = auth.uid()
    or is_admin()
  )
  with check (user_id = auth.uid());

-- ============================================================
-- BOOK LIST ITEMS
-- ============================================================

alter table book_list_items enable row level security;

create policy "list_items: leitura" on book_list_items
  for select using (
    is_admin()
    or exists (
      select 1 from book_lists
      where id = list_id
      and (visibility = 'public' or user_id = auth.uid())
    )
  );

create policy "list_items: crud" on book_list_items
  for all using (
    is_admin()
    or exists (
      select 1 from book_lists
      where id = list_id
      and user_id = auth.uid()
    )
  );

-- ============================================================
-- ACHIEVEMENTS
-- ============================================================

alter table achievements enable row level security;

create policy "achievements: leitura pública" on achievements
  for select using (true);

create policy "achievements: admin" on achievements
  for all using (is_admin());

-- ============================================================
-- USER ACHIEVEMENTS
-- ============================================================

alter table user_achievements enable row level security;

create policy "user_achievements: próprias" on user_achievements
  for select using (
    user_id = auth.uid()
    or is_admin()
  );

create policy "user_achievements: inserir" on user_achievements
  for insert with check (user_id = auth.uid());

-- ============================================================
-- SUBSCRIPTIONS (spec §17: fonte única de verdade)
-- ============================================================

alter table subscriptions enable row level security;

-- Usuário vê sua própria assinatura; admin vê todas
create policy "subscriptions: leitura" on subscriptions
  for select using (
    user_id = auth.uid()
    or is_admin()
  );

-- Escrita exclusiva via Edge Functions (service_role) ou admin
create policy "subscriptions: admin" on subscriptions
  for all using (is_admin());

-- ============================================================
-- REPORTS
-- ============================================================

alter table reports enable row level security;

-- Reporter vê apenas os próprios; admin/moderador vê todos
create policy "reports: leitura" on reports
  for select using (
    reporter_id = auth.uid()
    or is_admin()
    or current_user_role() in ('moderator', 'support')
  );

create policy "reports: criar" on reports
  for insert with check (
    reporter_id = auth.uid()
    and is_active_user()
  );

create policy "reports: admin resolve" on reports
  for update using (
    is_admin()
    or current_user_role() in ('moderator', 'support')
  );

-- ============================================================
-- AUDIT LOGS (spec §10: imutável — INSERT only)
-- ============================================================

alter table audit_logs enable row level security;

-- Usuário vê apenas os próprios logs (como ator); admin vê tudo
create policy "audit_logs: leitura" on audit_logs
  for select using (
    actor_id = auth.uid()
    or is_admin()
    or current_user_role() in ('support', 'moderator')
  );

-- INSERT permitido a qualquer usuário autenticado (logs de usuário)
-- UPDATE e DELETE bloqueados pelas rules no schema
create policy "audit_logs: inserir" on audit_logs
  for insert with check (true);

-- ============================================================
-- FEATURE FLAGS (spec §19: admin gerencia)
-- ============================================================

alter table feature_flags enable row level security;

create policy "feature_flags: leitura autenticada" on feature_flags
  for select using (auth.uid() is not null);

create policy "feature_flags: admin" on feature_flags
  for all using (is_admin());

-- ============================================================
-- INVITES
-- ============================================================

alter table invites enable row level security;

create policy "invites: admin" on invites
  for all using (is_admin());

-- Qualquer pessoa pode verificar um código de convite (para usar)
create policy "invites: verificar código" on invites
  for select using (
    code = current_setting('app.invite_code', true)
    or used_by = auth.uid()
    or is_admin()
  );

-- ============================================================
-- LGPD REQUESTS (spec §11)
-- ============================================================

alter table lgpd_requests enable row level security;

create policy "lgpd: própria" on lgpd_requests
  for select using (
    user_id = auth.uid()
    or is_admin()
  );

create policy "lgpd: solicitar" on lgpd_requests
  for insert with check (user_id = auth.uid());

create policy "lgpd: admin processa" on lgpd_requests
  for update using (is_admin());

-- ============================================================
-- PUSH TOKENS
-- ============================================================

alter table push_tokens enable row level security;

create policy "push_tokens: próprios" on push_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "push_tokens: admin" on push_tokens
  for select using (is_admin());
