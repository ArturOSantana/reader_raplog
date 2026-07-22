-- ============================================================
-- FIX: Recursão infinita nas policies de book_club_members
--
-- Causa: as policies de SELECT/UPDATE/DELETE consultavam a
-- própria tabela book_club_members dentro do USING(), causando
-- recursão infinita (código 42P17).
--
-- Solução: funções SECURITY DEFINER que bypassam o RLS ao
-- consultar book_club_members internamente.
-- ============================================================

-- 1. Remove policies problemáticas
DROP POLICY IF EXISTS "club_members: member select"     ON book_club_members;
DROP POLICY IF EXISTS "club_members: self insert"       ON book_club_members;
DROP POLICY IF EXISTS "club_members: moderator update"  ON book_club_members;
DROP POLICY IF EXISTS "club_members: self or admin delete" ON book_club_members;

-- 2. Cria funções auxiliares SECURITY DEFINER
--    (executam como owner da função, sem acionar RLS da tabela)

CREATE OR REPLACE FUNCTION is_club_member(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id AND user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION is_club_moderator(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role IN ('admin', 'moderator')
  );
$$;

CREATE OR REPLACE FUNCTION is_club_admin(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role = 'admin'
  );
$$;

-- 3. Recria as policies usando as funções (sem auto-referência)

CREATE POLICY "club_members: member select"
  ON book_club_members FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

CREATE POLICY "club_members: self insert"
  ON book_club_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "club_members: moderator update"
  ON book_club_members FOR UPDATE
  USING (is_club_moderator(club_id, auth.uid()));

CREATE POLICY "club_members: self or admin delete"
  ON book_club_members FOR DELETE
  USING (
    auth.uid() = user_id OR
    is_club_admin(club_id, auth.uid())
  );
