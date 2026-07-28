-- ============================================================
-- READLOG — Leitor Mentor
-- Adiciona o papel 'mentor' ao book_club_members.
-- O mentor é um membro experiente com permissões delegadas
-- pelo owner: criar desafios, acolher novos membros e enviar
-- nudges — sem ser admin/owner.
-- ============================================================

-- ── 1. Adiciona 'mentor' ao CHECK de role ────────────────────
-- O campo role já existe em book_club_members.
-- Recriamos o constraint para incluir o novo valor.
ALTER TABLE book_club_members
  DROP CONSTRAINT IF EXISTS book_club_members_role_check;

ALTER TABLE book_club_members
  ADD CONSTRAINT book_club_members_role_check
  CHECK (role IN ('owner', 'admin', 'mentor', 'member'));

-- ── 2. Helper: verificar se usuário é mentor do clube ────────
CREATE OR REPLACE FUNCTION is_club_mentor(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role    IN ('owner', 'admin', 'mentor')
  );
$$;

GRANT EXECUTE ON FUNCTION is_club_mentor(UUID, UUID) TO authenticated;

-- ── 3. RPC: promover/rebaixar mentor ─────────────────────────
-- Apenas owner ou admin pode promover um membro a mentor.
CREATE OR REPLACE FUNCTION set_club_mentor(
  p_club_id  UUID,
  p_user_id  UUID,
  p_promote  BOOLEAN DEFAULT TRUE   -- TRUE = promover, FALSE = remover papel
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_role TEXT;
BEGIN
  IF NOT is_club_manager(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Apenas owner ou admin pode gerenciar mentores';
  END IF;

  -- Não pode alterar o próprio role
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Você não pode alterar o próprio papel';
  END IF;

  v_new_role := CASE p_promote WHEN TRUE THEN 'mentor' ELSE 'member' END;

  UPDATE book_club_members
  SET role = v_new_role
  WHERE club_id = p_club_id
    AND user_id = p_user_id
    AND role NOT IN ('owner', 'admin');  -- protege owner e admin

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro não encontrado ou não pode ser alterado';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_club_mentor(UUID, UUID, BOOLEAN) TO authenticated;

-- ── 4. RPC: mentor dá boas-vindas a novo membro ──────────────
-- Publica uma mensagem de boas-vindas no feed do clube quando
-- um mentor recepciona um novo membro.
CREATE OR REPLACE FUNCTION mentor_welcome_member(
  p_club_id       UUID,
  p_new_member_id UUID,
  p_message       TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_member_name TEXT;
  v_msg             TEXT;
BEGIN
  IF NOT is_club_mentor(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Apenas mentores podem dar boas-vindas';
  END IF;

  SELECT name INTO v_new_member_name FROM profiles WHERE id = p_new_member_id;

  v_msg := COALESCE(
    p_message,
    'Bem-vindo(a) ao clube, ' || COALESCE(v_new_member_name, 'novo leitor') || '! 📚'
  );

  INSERT INTO social_feed (user_id, event_type, club_id, book_title)
  VALUES (auth.uid(), 'joined_club', p_club_id, v_msg);
END;
$$;

GRANT EXECUTE ON FUNCTION mentor_welcome_member(UUID, UUID, TEXT) TO authenticated;
