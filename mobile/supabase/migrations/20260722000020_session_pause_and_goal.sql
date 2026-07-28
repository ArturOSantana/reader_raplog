-- ============================================================
-- READLOG — Melhoria da entidade reading_sessions
--           Adiciona: status, paused_duration_seconds,
--                     session_goal, goal_value
-- ============================================================

-- Novos campos na tabela reading_sessions
ALTER TABLE reading_sessions
  ADD COLUMN IF NOT EXISTS status                TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'finished', 'cancelled')),
  ADD COLUMN IF NOT EXISTS paused_duration_seconds INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS session_goal           TEXT
    CHECK (session_goal IN ('byTime', 'byPage', 'dailyGoal', 'freeReading')),
  ADD COLUMN IF NOT EXISTS goal_value             INTEGER;

-- Migra sessões antigas: se tem ended_at → finished, senão → active
UPDATE reading_sessions
SET status = 'finished'
WHERE ended_at IS NOT NULL AND status = 'active';

-- Índice para buscar sessões ativas rapidamente
CREATE INDEX IF NOT EXISTS idx_reading_sessions_status
  ON reading_sessions (user_id, status);

-- ── Atualiza a função calculate_streak para ignorar sessões canceladas ──────
CREATE OR REPLACE FUNCTION calculate_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_streak  INTEGER := 0;
  v_cursor  DATE    := CURRENT_DATE;
  v_date    DATE;
BEGIN
  FOR v_date IN
    SELECT DISTINCT DATE(started_at AT TIME ZONE 'UTC')
    FROM reading_sessions
    WHERE user_id = p_user_id
      AND status   = 'finished'
    ORDER BY 1 DESC
  LOOP
    IF v_date >= v_cursor - INTERVAL '1 day' THEN
      v_streak := v_streak + 1;
      v_cursor  := v_date;
    ELSE
      EXIT;
    END IF;
  END LOOP;
  RETURN v_streak;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_streak(UUID) TO authenticated;
