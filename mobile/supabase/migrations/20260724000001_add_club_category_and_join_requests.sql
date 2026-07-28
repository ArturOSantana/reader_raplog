-- ============================================================
-- READLOG — Categoria do Clube + Solicitações de Entrada
-- M-01: coluna category em book_clubs
--        tabela club_join_requests para aprovação em clubes privados
-- ============================================================

-- ── 1. Categoria do clube ────────────────────────────────────────────────────

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general'
    CHECK (category IN (
      'general',        -- Geral
      'fiction',        -- Ficção
      'nonfiction',     -- Não-ficção
      'fantasy',        -- Fantasia
      'scifi',          -- Ficção científica
      'romance',        -- Romance
      'mystery',        -- Mistério / Thriller
      'biography',      -- Biografias
      'history',        -- História
      'selfhelp',       -- Autoajuda
      'children',       -- Infantojuvenil
      'classics'        -- Clássicos
    ));

-- ── 2. Tabela de solicitações de entrada ──────────────────────────────────────
-- Usada quando visibility = 'private' e o usuário quer entrar sem convite.
-- Um admin/dono aprova ou rejeita cada solicitação.

CREATE TABLE IF NOT EXISTS club_join_requests (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     UUID        NOT NULL REFERENCES book_clubs(id)  ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  status      TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'approved', 'rejected')),
  message     TEXT,                             -- mensagem opcional do solicitante
  reviewed_by UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (club_id, user_id)                     -- uma solicitação por par clube/usuário
);

CREATE INDEX IF NOT EXISTS idx_join_requests_club_pending
  ON club_join_requests(club_id, status)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_join_requests_user
  ON club_join_requests(user_id);

-- ── 3. RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE club_join_requests ENABLE ROW LEVEL SECURITY;

-- Solicitante vê as próprias solicitações
CREATE POLICY "join_requests: self select"
  ON club_join_requests FOR SELECT
  USING (auth.uid() = user_id);

-- Manager do clube vê todas as solicitações pendentes
CREATE POLICY "join_requests: manager select"
  ON club_join_requests FOR SELECT
  USING (is_club_manager(club_id, auth.uid()));

-- Qualquer autenticado pode criar (solicitar entrar)
CREATE POLICY "join_requests: self insert"
  ON club_join_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Manager pode atualizar (aprovar / rejeitar)
CREATE POLICY "join_requests: manager update"
  ON club_join_requests FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

-- Solicitante pode cancelar a própria solicitação pendente
CREATE POLICY "join_requests: self delete"
  ON club_join_requests FOR DELETE
  USING (auth.uid() = user_id AND status = 'pending');

GRANT SELECT, INSERT, DELETE ON TABLE club_join_requests TO authenticated;
GRANT UPDATE ON TABLE club_join_requests TO authenticated;

-- ── 4. RPC: aprovar solicitação ───────────────────────────────────────────────
-- Aprova a solicitação e insere o usuário como membro.

CREATE OR REPLACE FUNCTION approve_join_request(p_request_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
  v_user_id UUID;
BEGIN
  SELECT club_id, user_id
  INTO v_club_id, v_user_id
  FROM club_join_requests
  WHERE id = p_request_id AND status = 'pending';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Solicitação não encontrada ou já processada';
  END IF;

  IF NOT is_club_manager(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Aprova a solicitação
  UPDATE club_join_requests
  SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
  WHERE id = p_request_id;

  -- Insere como membro (ignora se já for membro)
  INSERT INTO book_club_members (club_id, user_id, role)
  VALUES (v_club_id, v_user_id, 'member')
  ON CONFLICT (club_id, user_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION approve_join_request(UUID) TO authenticated;

-- ── 5. RPC: rejeitar solicitação ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION reject_join_request(p_request_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  SELECT club_id INTO v_club_id
  FROM club_join_requests
  WHERE id = p_request_id AND status = 'pending';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Solicitação não encontrada ou já processada';
  END IF;

  IF NOT is_club_manager(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE club_join_requests
  SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = NOW()
  WHERE id = p_request_id;
END;
$$;

GRANT EXECUTE ON FUNCTION reject_join_request(UUID) TO authenticated;
