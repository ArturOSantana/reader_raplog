-- ============================================================
-- Adiciona FK de social_feed.user_id → profiles.id para que o
-- PostgREST consiga resolver o join `profile:profiles(...)` na
-- query do feed social.
-- Também adiciona policy de leitura pública de perfis (nome e
-- avatar), necessária para exibir dados de outros usuários no feed.
-- Execute no SQL Editor do Supabase Dashboard
-- ============================================================

-- social_feed.user_id → profiles.id
ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- Permite que usuários autenticados leiam nome/avatar de qualquer perfil
-- (necessário para o feed social exibir dados de amigos)
CREATE POLICY "profiles: authenticated read"
  ON profiles FOR SELECT
  USING (auth.role() = 'authenticated');
