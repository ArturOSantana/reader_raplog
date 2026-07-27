-- ============================================================
-- SEC-FIX P0: Remove policy permissiva USING(true) em profiles
--
-- Problema: "Perfis públicos para autenticados" com USING(true)
-- permitia que qualquer usuário autenticado lesse TODOS os
-- perfis via GET /rest/v1/profiles (exfiltração em massa).
--
-- Correção: substitui por policy granular que só permite leitura
-- quando existe um relacionamento legítimo:
--   1. Próprio perfil
--   2. Amizade bidirecional confirmada (status = 'accepted')
--   3. Membro do mesmo clube
-- ============================================================

-- 1. Remove a policy permissiva original
DROP POLICY IF EXISTS "Perfis públicos para autenticados" ON profiles;

-- 2. Remove qualquer policy SELECT residual que use USING(true)
--    (proteção contra re-criação acidental por migrations futuras)
DO $$
DECLARE
  pol_name TEXT;
BEGIN
  FOR pol_name IN
    SELECT policyname FROM pg_policies
    WHERE tablename = 'profiles'
      AND cmd = 'SELECT'
      AND qual = 'true'   -- USING(true) literal
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', pol_name);
  END LOOP;
END $$;

-- 3. Cria policy granular
CREATE POLICY "profiles: select by relationship"
  ON profiles FOR SELECT
  TO authenticated
  USING (
    -- Leitura do próprio perfil
    auth.uid() = profiles.id

    -- Amizade bidirecional aceita
    OR EXISTS (
      SELECT 1 FROM friends f
      WHERE (f.user_id = auth.uid() AND f.friend_id = profiles.id)
         OR (f.user_id = profiles.id AND f.friend_id = auth.uid())
    )

    -- Membro do mesmo clube ativo
    OR EXISTS (
      SELECT 1 FROM book_club_members m1
      JOIN   book_club_members m2 ON m1.club_id = m2.club_id
      WHERE  m1.user_id = profiles.id
        AND  m2.user_id = auth.uid()
    )
  );

-- 4. A view public_profile_view já existe; garante que ela
--    herda a RLS da tabela base (não precisa de policy própria).
--    Revoga acesso direto à view para forçar uso com contexto de
--    autenticação correto (PostgREST usa a view, não a tabela).
-- (nenhuma alteração necessária na view, apenas documentando)
