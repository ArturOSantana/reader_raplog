-- ============================================================
-- READLOG — Dias de Descanso por Desafio (F-01)
-- Permite que membros "gastem" dias de descanso planejados
-- sem quebrar a ofensiva (streak) do desafio.
-- ============================================================

-- ── 1. Coluna em club_challenges ─────────────────────────────
ALTER TABLE club_challenges
  ADD COLUMN IF NOT EXISTS allowed_rest_days INTEGER NOT NULL DEFAULT 0
    CHECK (allowed_rest_days BETWEEN 0 AND 30);

-- ── 2. Tabela de uso de rest days ────────────────────────────
CREATE TABLE IF NOT EXISTS challenge_rest_day_usage (
  challenge_id   UUID        NOT NULL REFERENCES club_challenges(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  rest_date      DATE        NOT NULL,
  reason         TEXT        CHECK (char_length(reason) <= 200),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (challenge_id, user_id, rest_date)
);

CREATE INDEX IF NOT EXISTS idx_rest_day_usage_challenge
  ON challenge_rest_day_usage(challenge_id, user_id);

ALTER TABLE challenge_rest_day_usage ENABLE ROW LEVEL SECURITY;

-- Membro vê apenas os próprios registros
CREATE POLICY "rest_days: self select"
  ON challenge_rest_day_usage FOR SELECT
  USING (auth.uid() = user_id);

-- Manager do clube pode ver todos (útil para auditoria)
CREATE POLICY "rest_days: manager select"
  ON challenge_rest_day_usage FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM club_challenges cc
      WHERE cc.id = challenge_id
        AND is_club_manager(cc.club_id, auth.uid())
    )
  );

CREATE POLICY "rest_days: self insert"
  ON challenge_rest_day_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "rest_days: self delete"
  ON challenge_rest_day_usage FOR DELETE
  USING (
    auth.uid() = user_id
    -- Só pode cancelar no próprio dia (não retroativamente)
    AND rest_date = CURRENT_DATE
  );

GRANT SELECT, INSERT, DELETE ON TABLE challenge_rest_day_usage TO authenticated;

-- ── 3. RPC: marcar dia de descanso ───────────────────────────
CREATE OR REPLACE FUNCTION use_challenge_rest_day(
  p_challenge_id UUID,
  p_date         DATE    DEFAULT CURRENT_DATE,
  p_reason       TEXT    DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id   UUID;
  v_allowed   INTEGER;
  v_starts_at TIMESTAMPTZ;
  v_ends_at   TIMESTAMPTZ;
  v_used      INTEGER;
BEGIN
  SELECT club_id, allowed_rest_days, starts_at, ends_at
  INTO v_club_id, v_allowed, v_starts_at, v_ends_at
  FROM club_challenges
  WHERE id = p_challenge_id AND status = 'active';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado ou inativo';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  IF p_date NOT BETWEEN v_starts_at::DATE AND v_ends_at::DATE THEN
    RAISE EXCEPTION 'Data fora do período do desafio';
  END IF;

  IF v_allowed = 0 THEN
    RAISE EXCEPTION 'Este desafio não permite dias de descanso';
  END IF;

  SELECT COUNT(*)
  INTO v_used
  FROM challenge_rest_day_usage
  WHERE challenge_id = p_challenge_id
    AND user_id = auth.uid();

  IF v_used >= v_allowed THEN
    RAISE EXCEPTION 'Todos os % dia(s) de descanso já foram utilizados', v_allowed;
  END IF;

  INSERT INTO challenge_rest_day_usage (challenge_id, user_id, rest_date, reason)
  VALUES (p_challenge_id, auth.uid(), p_date, p_reason)
  ON CONFLICT DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION use_challenge_rest_day(UUID, DATE, TEXT) TO authenticated;
