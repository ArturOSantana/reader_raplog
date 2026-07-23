-- ============================================================
-- READLOG V2 — Momento do Clube
-- ============================================================
-- Horário fixo diário para leitura coletiva.
-- O admin define um horário no clube; membros recebem push
-- naquele horário com "X membros já confirmaram para hoje".
-- ============================================================

-- ── 1. Coluna em book_clubs ────────────────────────────────────────────────────

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS reading_moment_time  TIME,            -- ex: '21:00'
  ADD COLUMN IF NOT EXISTS reading_moment_label TEXT,            -- ex: "Momento do Livro"
  ADD COLUMN IF NOT EXISTS reading_moment_active BOOLEAN NOT NULL DEFAULT FALSE;

-- ── 2. Tabela de confirmações do Momento ─────────────────────────────────────
-- Um membro confirma presença para um determinado dia.

CREATE TABLE IF NOT EXISTS club_moment_confirmations (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id      UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  confirmed_at DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (club_id, user_id, confirmed_at)
);

CREATE INDEX IF NOT EXISTS idx_moment_confirmations_club_date
  ON club_moment_confirmations(club_id, confirmed_at DESC);

ALTER TABLE club_moment_confirmations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "moment: member select"
  ON club_moment_confirmations FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

CREATE POLICY "moment: member insert"
  ON club_moment_confirmations FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND is_club_member(club_id, auth.uid())
  );

CREATE POLICY "moment: self delete"
  ON club_moment_confirmations FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON TABLE club_moment_confirmations TO authenticated;

-- ── 3. RPC: confirmar presença no Momento de hoje ────────────────────────────

CREATE OR REPLACE FUNCTION confirm_reading_moment(p_club_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  INSERT INTO club_moment_confirmations (club_id, user_id, confirmed_at)
  VALUES (p_club_id, auth.uid(), CURRENT_DATE)
  ON CONFLICT (club_id, user_id, confirmed_at) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION confirm_reading_moment(UUID) TO authenticated;

-- ── 4. RPC: contar confirmações do dia ───────────────────────────────────────

CREATE OR REPLACE FUNCTION moment_confirmations_today(p_club_id UUID)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM club_moment_confirmations
  WHERE club_id = p_club_id
    AND confirmed_at = CURRENT_DATE;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION moment_confirmations_today(UUID) TO authenticated;

-- ── 5. RPC: verificar se usuário atual confirmou hoje ────────────────────────

CREATE OR REPLACE FUNCTION user_confirmed_moment_today(p_club_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM club_moment_confirmations
    WHERE club_id = p_club_id
      AND user_id  = auth.uid()
      AND confirmed_at = CURRENT_DATE
  );
END;
$$;

GRANT EXECUTE ON FUNCTION user_confirmed_moment_today(UUID) TO authenticated;
