-- ============================================================
-- READLOG — RPC para criação de clube
--
-- A migration sec_fix_restrict_grants (20260730000005) revogou
-- INSERT direto em book_clubs de authenticated. O app precisa
-- de uma função SECURITY DEFINER para executar o INSERT em
-- nome do usuário de forma controlada e segura.
-- ============================================================

CREATE OR REPLACE FUNCTION create_club(
  p_name        TEXT,
  p_description TEXT  DEFAULT NULL,
  p_cover_url   TEXT  DEFAULT NULL,
  p_visibility  TEXT  DEFAULT 'private'
)
RETURNS SETOF book_clubs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_club    book_clubs;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Valida visibilidade
  IF p_visibility NOT IN ('public', 'private') THEN
    RAISE EXCEPTION 'invalid_visibility';
  END IF;

  -- Insere o clube (trigger gera o invite_code automaticamente)
  INSERT INTO book_clubs (admin_id, name, description, cover_url, visibility)
  VALUES (v_user_id, p_name, p_description, p_cover_url, p_visibility)
  RETURNING * INTO v_club;

  -- Criador entra como owner
  INSERT INTO book_club_members (club_id, user_id, role)
  VALUES (v_club.id, v_user_id, 'owner');

  RETURN NEXT v_club;
END;
$$;

-- Apenas usuários autenticados podem chamar esta função
REVOKE ALL ON FUNCTION create_club(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_club(TEXT, TEXT, TEXT, TEXT) TO authenticated;
