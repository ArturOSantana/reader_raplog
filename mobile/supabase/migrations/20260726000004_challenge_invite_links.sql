-- ============================================================
-- READLOG — Links de Convite para Desafios (F-07)
-- Convite direto ao desafio ativo via token/deep-link.
-- Ao usar o link, o usuário entra no clube (se não for membro)
-- e é direcionado para o desafio específico.
-- ============================================================

-- ── 1. Tabela de links de convite ────────────────────────────
CREATE TABLE IF NOT EXISTS challenge_invite_links (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id   UUID        NOT NULL REFERENCES club_challenges(id) ON DELETE CASCADE,
  club_id        UUID        NOT NULL REFERENCES book_clubs(id)      ON DELETE CASCADE,
  created_by     UUID        NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  -- Token URL-safe de 16 caracteres derivado de gen_random_uuid() (sem dependência externa)
  token          TEXT        NOT NULL UNIQUE
                               DEFAULT replace(replace(encode(uuid_send(gen_random_uuid()), 'base64'), '+', '-'), '/', '_'),
  label          TEXT        CHECK (char_length(label) <= 100),  -- ex: "Campanha Verão"
  max_uses       INTEGER     CHECK (max_uses > 0),               -- NULL = ilimitado
  use_count      INTEGER     NOT NULL DEFAULT 0,
  expires_at     TIMESTAMPTZ,                                    -- NULL = sem expiração
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_challenge_invite_token
  ON challenge_invite_links(token)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_challenge_invite_challenge
  ON challenge_invite_links(challenge_id);

ALTER TABLE challenge_invite_links ENABLE ROW LEVEL SECURITY;

-- Membros do clube veem os links do clube
CREATE POLICY "challenge_invite: member select"
  ON challenge_invite_links FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Apenas managers criam links
CREATE POLICY "challenge_invite: manager insert"
  ON challenge_invite_links FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
    AND is_club_manager(club_id, auth.uid())
  );

-- Apenas managers desativam/editam links
CREATE POLICY "challenge_invite: manager update"
  ON challenge_invite_links FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE ON TABLE challenge_invite_links TO authenticated;

-- ── 2. RPC: entrar no desafio via token ──────────────────────
-- Retorna o club_id e challenge_id para o app navegar à tela correta.
CREATE OR REPLACE FUNCTION join_via_challenge_invite(p_token TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_link     challenge_invite_links%ROWTYPE;
  v_status   TEXT;
BEGIN
  SELECT * INTO v_link
  FROM challenge_invite_links
  WHERE token = p_token AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Link inválido ou desativado';
  END IF;

  IF v_link.expires_at IS NOT NULL AND v_link.expires_at < NOW() THEN
    RAISE EXCEPTION 'Link expirado';
  END IF;

  IF v_link.max_uses IS NOT NULL AND v_link.use_count >= v_link.max_uses THEN
    RAISE EXCEPTION 'Limite de usos atingido';
  END IF;

  SELECT status INTO v_status
  FROM club_challenges
  WHERE id = v_link.challenge_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado';
  END IF;

  IF v_status != 'active' THEN
    RAISE EXCEPTION 'Este desafio não está mais ativo';
  END IF;

  -- Entra no clube como membro se ainda não for
  INSERT INTO book_club_members (club_id, user_id, role)
  VALUES (v_link.club_id, auth.uid(), 'member')
  ON CONFLICT (club_id, user_id) DO NOTHING;

  -- Incrementa contador de uso
  UPDATE challenge_invite_links
  SET use_count = use_count + 1
  WHERE id = v_link.id;

  RETURN jsonb_build_object(
    'club_id',      v_link.club_id,
    'challenge_id', v_link.challenge_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION join_via_challenge_invite(TEXT) TO authenticated;

-- ── 3. RPC: criar link de convite ────────────────────────────
CREATE OR REPLACE FUNCTION create_challenge_invite_link(
  p_challenge_id UUID,
  p_label        TEXT    DEFAULT NULL,
  p_max_uses     INTEGER DEFAULT NULL,
  p_expires_at   TIMESTAMPTZ DEFAULT NULL
)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
  v_token   TEXT;
BEGIN
  SELECT club_id INTO v_club_id
  FROM club_challenges WHERE id = p_challenge_id AND status = 'active';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado ou inativo';
  END IF;

  IF NOT is_club_manager(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  INSERT INTO challenge_invite_links
    (challenge_id, club_id, created_by, label, max_uses, expires_at)
  VALUES
    (p_challenge_id, v_club_id, auth.uid(), p_label, p_max_uses, p_expires_at)
  RETURNING token INTO v_token;

  RETURN v_token;
END;
$$;

GRANT EXECUTE ON FUNCTION create_challenge_invite_link(UUID, TEXT, INTEGER, TIMESTAMPTZ) TO authenticated;
