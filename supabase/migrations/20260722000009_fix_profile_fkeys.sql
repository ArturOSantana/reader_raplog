-- ============================================================
-- Garante que todas as FKs para profiles existam, permitindo
-- que o PostgREST resolva os joins usados pelo app Flutter.
-- Usa DROP/ADD idempotente para ser seguro re-executar.
-- ============================================================

-- ── friends.friend_id → profiles.id ─────────────────────────
ALTER TABLE friends
  DROP CONSTRAINT IF EXISTS friends_friend_id_fkey;

ALTER TABLE friends
  ADD CONSTRAINT friends_friend_id_fkey
  FOREIGN KEY (friend_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── friend_requests.sender_id → profiles.id ─────────────────
ALTER TABLE friend_requests
  DROP CONSTRAINT IF EXISTS friend_requests_sender_id_fkey;

ALTER TABLE friend_requests
  ADD CONSTRAINT friend_requests_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── friend_requests.receiver_id → profiles.id ───────────────
ALTER TABLE friend_requests
  DROP CONSTRAINT IF EXISTS friend_requests_receiver_id_fkey;

ALTER TABLE friend_requests
  ADD CONSTRAINT friend_requests_receiver_id_fkey
  FOREIGN KEY (receiver_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── social_feed.user_id → profiles.id ───────────────────────
ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_user_id_fkey;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── Backfill: cria perfis faltantes antes de adicionar FKs ───
-- Garante que não há user_ids orfaos em nenhuma tabela que
-- vai receber FK para profiles.
-- username usa o prefixo do e-mail como fallback para satisfazer
-- eventuais constraints (será removido na migration _013).
INSERT INTO profiles (id, username, updated_at)
SELECT
  u.id,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(u.email, '@', 1),
    u.id::text
  ),
  NOW()
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- ── book_club_members.user_id → profiles.id ─────────────────
ALTER TABLE book_club_members
  DROP CONSTRAINT IF EXISTS book_club_members_user_id_profiles_fkey;

ALTER TABLE book_club_members
  ADD CONSTRAINT book_club_members_user_id_profiles_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ── Política de leitura de perfis para feed/amigos ───────────
-- DROP IF EXISTS para não falhar caso já exista de _002 ou _005
DROP POLICY IF EXISTS "profiles: authenticated read" ON profiles;

CREATE POLICY "profiles: authenticated read"
  ON profiles FOR SELECT
  USING (auth.role() = 'authenticated');
