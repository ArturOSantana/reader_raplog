-- ============================================================
-- READLOG — Fix: club_challenge_progress × auto_link_sessions
-- Bug: a RPC sempre contava de reading_sessions, mesmo quando
-- auto_link_sessions = FALSE — desafios manuais apareciam com
-- progresso zerado pois os check-ins em challenge_manual_checkins
-- nunca eram considerados.
-- Correção: quando auto_link_sessions = FALSE, conta de
-- challenge_manual_checkins; caso contrário mantém reading_sessions.
-- ============================================================

CREATE OR REPLACE FUNCTION club_challenge_progress(p_challenge_id UUID)
RETURNS TABLE (
  user_id       UUID,
  user_name     TEXT,
  avatar_url    TEXT,
  current_value BIGINT,
  goal_value    INTEGER,
  pct_complete  NUMERIC,
  rank          INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id         UUID;
  v_goal_type       TEXT;
  v_goal_value      INTEGER;
  v_starts_at       TIMESTAMPTZ;
  v_ends_at         TIMESTAMPTZ;
  v_auto_link       BOOLEAN;
BEGIN
  SELECT club_id, goal_type, c.goal_value, starts_at, ends_at, auto_link_sessions
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at, v_auto_link
  FROM club_challenges c WHERE c.id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- ── Desafio com check-in AUTOMÁTICO (lê de reading_sessions) ─────────────
  IF v_auto_link THEN
    RETURN QUERY
    WITH raw AS (
      SELECT
        bcm.user_id,
        p.name        AS user_name,
        p.avatar_url,
        CASE v_goal_type
          WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
          WHEN 'minutes'  THEN COALESCE(SUM(rs.duration_minutes), 0)
          WHEN 'sessions' THEN COUNT(DISTINCT rs.id)
          WHEN 'checkins' THEN COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))
        END AS current_value
      FROM book_club_members bcm
      JOIN profiles p ON p.id = bcm.user_id
      LEFT JOIN reading_sessions rs
        ON rs.user_id    = bcm.user_id
       AND rs.status     = 'finished'
       AND rs.started_at >= v_starts_at
       AND rs.started_at <  v_ends_at
       AND EXISTS (
         SELECT 1 FROM books b
         WHERE b.id = rs.book_id
           AND b.source_club_id = v_club_id
       )
      WHERE bcm.club_id = v_club_id
      GROUP BY bcm.user_id, p.name, p.avatar_url
    )
    SELECT
      raw.user_id,
      raw.user_name,
      raw.avatar_url,
      raw.current_value,
      v_goal_value,
      LEAST(ROUND(raw.current_value::NUMERIC / v_goal_value * 100, 1), 100) AS pct_complete,
      ROW_NUMBER() OVER (ORDER BY raw.current_value DESC, raw.user_name ASC)::INTEGER AS rank
    FROM raw
    ORDER BY raw.current_value DESC, raw.user_name ASC;

  -- ── Desafio com check-in MANUAL (lê de challenge_manual_checkins) ─────────
  ELSE
    RETURN QUERY
    WITH raw AS (
      SELECT
        bcm.user_id,
        p.name        AS user_name,
        p.avatar_url,
        CASE v_goal_type
          WHEN 'pages'    THEN COALESCE(SUM(mc.pages_read)::BIGINT, 0)
          WHEN 'minutes'  THEN COALESCE(SUM(mc.minutes_read)::BIGINT, 0)
          WHEN 'sessions' THEN COUNT(DISTINCT mc.id)
          WHEN 'checkins' THEN COUNT(DISTINCT mc.checkin_date)
        END AS current_value
      FROM book_club_members bcm
      JOIN profiles p ON p.id = bcm.user_id
      LEFT JOIN challenge_manual_checkins mc
        ON mc.user_id      = bcm.user_id
       AND mc.challenge_id = p_challenge_id
       AND mc.checkin_date >= v_starts_at::DATE
       AND mc.checkin_date <  v_ends_at::DATE
      WHERE bcm.club_id = v_club_id
      GROUP BY bcm.user_id, p.name, p.avatar_url
    )
    SELECT
      raw.user_id,
      raw.user_name,
      raw.avatar_url,
      raw.current_value,
      v_goal_value,
      LEAST(ROUND(raw.current_value::NUMERIC / v_goal_value * 100, 1), 100) AS pct_complete,
      ROW_NUMBER() OVER (ORDER BY raw.current_value DESC, raw.user_name ASC)::INTEGER AS rank
    FROM raw
    ORDER BY raw.current_value DESC, raw.user_name ASC;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION club_challenge_progress(UUID) TO authenticated;
