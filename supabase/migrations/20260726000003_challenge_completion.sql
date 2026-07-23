-- ============================================================
-- READLOG — Encerramento de Desafio e Tela de Celebração (F-04)
-- Snapshot imutável de resultado gerado ao finalizar o desafio.
-- ============================================================

-- ── 1. Tabela de resultados (snapshot imutável) ───────────────
CREATE TABLE IF NOT EXISTS challenge_results (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id             UUID        NOT NULL UNIQUE
                             REFERENCES club_challenges(id) ON DELETE CASCADE,
  finalized_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finalized_by             UUID        REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Pódio: top 3
  first_user_id            UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  first_user_name          TEXT,
  first_value              BIGINT,

  second_user_id           UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  second_user_name         TEXT,
  second_value             BIGINT,

  third_user_id            UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  third_user_name          TEXT,
  third_value              BIGINT,

  -- Destaques
  longest_streak_user_id   UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  longest_streak_user_name TEXT,
  longest_streak_days      INTEGER,

  most_checkins_user_id    UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  most_checkins_user_name  TEXT,
  most_checkins_count      INTEGER,

  -- Totais do clube no desafio
  total_participants       INTEGER     NOT NULL DEFAULT 0,
  total_goal_completions   INTEGER     NOT NULL DEFAULT 0, -- quantos atingiram 100%
  total_pages              BIGINT      NOT NULL DEFAULT 0,
  total_minutes            BIGINT      NOT NULL DEFAULT 0,

  -- Snapshot do desafio
  goal_type                TEXT        NOT NULL,
  goal_value               INTEGER     NOT NULL,
  challenge_title          TEXT        NOT NULL,

  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_challenge_results_challenge
  ON challenge_results(challenge_id);

ALTER TABLE challenge_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "results: member select"
  ON challenge_results FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM club_challenges cc
      WHERE cc.id = challenge_id
        AND is_club_member(cc.club_id, auth.uid())
    )
  );

GRANT SELECT ON TABLE challenge_results TO authenticated;
-- INSERT/UPDATE via SECURITY DEFINER functions apenas
GRANT INSERT, UPDATE ON TABLE challenge_results TO authenticated;

-- ── 2. RPC: finalizar desafio ─────────────────────────────────
-- Pode ser chamado pelo admin manualmente OU pelo cron job automático.
-- Idempotente: se já foi finalizado, retorna o id existente.
CREATE OR REPLACE FUNCTION finalize_challenge(p_challenge_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id      UUID;
  v_goal_type    TEXT;
  v_goal_value   INTEGER;
  v_title        TEXT;
  v_existing_id  UUID;
  v_result_id    UUID;

  v_first_uid    UUID;  v_first_name  TEXT;  v_first_val  BIGINT;
  v_second_uid   UUID;  v_second_name TEXT;  v_second_val BIGINT;
  v_third_uid    UUID;  v_third_name  TEXT;  v_third_val  BIGINT;

  v_total_parts  INTEGER;
  v_total_comp   INTEGER;
  v_total_pages  BIGINT;
  v_total_mins   BIGINT;
BEGIN
  SELECT club_id, goal_type, goal_value, title
  INTO v_club_id, v_goal_type, v_goal_value, v_title
  FROM club_challenges
  WHERE id = p_challenge_id;

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado';
  END IF;

  -- Permissão: manager do clube
  IF NOT is_club_manager(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Apenas admins podem finalizar o desafio';
  END IF;

  -- Idempotência
  SELECT id INTO v_existing_id
  FROM challenge_results WHERE challenge_id = p_challenge_id;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  -- Monta pódio a partir da RPC existente
  SELECT
    MAX(user_id)       FILTER (WHERE rank = 1),
    MAX(user_name)     FILTER (WHERE rank = 1),
    MAX(current_value) FILTER (WHERE rank = 1),
    MAX(user_id)       FILTER (WHERE rank = 2),
    MAX(user_name)     FILTER (WHERE rank = 2),
    MAX(current_value) FILTER (WHERE rank = 2),
    MAX(user_id)       FILTER (WHERE rank = 3),
    MAX(user_name)     FILTER (WHERE rank = 3),
    MAX(current_value) FILTER (WHERE rank = 3),
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE pct_complete >= 100)::INTEGER,
    0::BIGINT,  -- total_pages calculado abaixo
    0::BIGINT
  INTO
    v_first_uid, v_first_name, v_first_val,
    v_second_uid, v_second_name, v_second_val,
    v_third_uid, v_third_name, v_third_val,
    v_total_parts, v_total_comp,
    v_total_pages, v_total_mins
  FROM club_challenge_progress(p_challenge_id);

  -- Totais de páginas e minutos no período do desafio
  SELECT
    COALESCE(SUM(rs.pages_read), 0),
    COALESCE(SUM(rs.duration_minutes), 0)
  INTO v_total_pages, v_total_mins
  FROM reading_sessions rs
  JOIN book_club_members bcm ON bcm.user_id = rs.user_id
  JOIN club_challenges cc    ON cc.id = p_challenge_id
  WHERE bcm.club_id  = v_club_id
    AND rs.status    = 'finished'
    AND rs.started_at >= cc.starts_at
    AND rs.started_at <  cc.ends_at;

  -- Grava o resultado
  INSERT INTO challenge_results (
    challenge_id, finalized_by,
    first_user_id,  first_user_name,  first_value,
    second_user_id, second_user_name, second_value,
    third_user_id,  third_user_name,  third_value,
    total_participants, total_goal_completions,
    total_pages, total_minutes,
    goal_type, goal_value, challenge_title
  ) VALUES (
    p_challenge_id, auth.uid(),
    v_first_uid,  v_first_name,  v_first_val,
    v_second_uid, v_second_name, v_second_val,
    v_third_uid,  v_third_name,  v_third_val,
    v_total_parts, v_total_comp,
    v_total_pages, v_total_mins,
    v_goal_type, v_goal_value, v_title
  ) RETURNING id INTO v_result_id;

  -- Marca desafio como finalizado
  UPDATE club_challenges
  SET status = 'finished'
  WHERE id = p_challenge_id;

  -- Notifica todos os membros do clube
  PERFORM notify_club_members(
    v_club_id,
    'clubs',
    'challenge_finished',
    'Desafio encerrado! Veja o resultado 🏆',
    v_title,
    '/clubs/' || v_club_id || '/challenges/' || p_challenge_id || '/result',
    auth.uid()
  );

  RETURN v_result_id;
END;
$$;

GRANT EXECUTE ON FUNCTION finalize_challenge(UUID) TO authenticated;

-- ── 3. Adiciona event_type 'challenge_finished' ao feed ───────
ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_event_type_check;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_event_type_check
  CHECK (event_type IN (
    'finished_book', 'started_book', 'streak', 'achievement',
    'goal_completed', 'reading_session', 'joined_club',
    'bet_resolved', 'poll_opened', 'poll_closed',
    'challenge_started', 'challenge_finished'
  ));
