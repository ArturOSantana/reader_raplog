-- ============================================================
-- READLOG — RPC: progresso coletivo do desafio + contribuição
-- individual como percentual do total do clube.
--
-- Funções criadas:
--   club_challenge_collective_progress(p_challenge_id)
--   challenge_my_contribution_pct(p_challenge_id)
-- ============================================================

-- ── 1. Progresso coletivo ──────────────────────────────────────────────────────
-- Retorna uma única linha com o somatório de todos os membros,
-- a meta total do clube (goal_value × nº membros) e estatísticas
-- de participação. Suporta tanto auto_link_sessions quanto manual.

CREATE OR REPLACE FUNCTION club_challenge_collective_progress(
  p_challenge_id UUID
)
RETURNS TABLE (
  current_value  BIGINT,
  target_value   BIGINT,
  pct_complete   NUMERIC,
  days_left      INTEGER,
  total_members  INTEGER,
  active_members INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_goal_value INTEGER;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
  v_auto_link  BOOLEAN;
  v_members    INTEGER;
BEGIN
  SELECT club_id, goal_type, c.goal_value, starts_at, ends_at, auto_link_sessions
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at, v_auto_link
  FROM club_challenges c WHERE c.id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT COUNT(*) INTO v_members
  FROM book_club_members WHERE club_id = v_club_id;

  IF v_auto_link THEN
    RETURN QUERY
    WITH per_member AS (
      SELECT
        bcm.user_id,
        CASE v_goal_type
          WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
          WHEN 'minutes'  THEN COALESCE(SUM(rs.duration_minutes), 0)
          WHEN 'sessions' THEN COUNT(DISTINCT rs.id)
          WHEN 'checkins' THEN COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))
        END AS contrib
      FROM book_club_members bcm
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
      GROUP BY bcm.user_id
    ),
    totals AS (
      SELECT
        COALESCE(SUM(contrib), 0)                         AS cur,
        (v_goal_value::BIGINT * v_members)                AS tgt,
        COUNT(*) FILTER (WHERE contrib > 0)::INTEGER      AS active
      FROM per_member
    )
    SELECT
      totals.cur::BIGINT,
      totals.tgt::BIGINT,
      LEAST(ROUND(totals.cur::NUMERIC / NULLIF(totals.tgt, 0) * 100, 1), 100),
      (v_ends_at::DATE - CURRENT_DATE)::INTEGER,
      v_members,
      totals.active
    FROM totals;

  ELSE
    RETURN QUERY
    WITH per_member AS (
      SELECT
        bcm.user_id,
        CASE v_goal_type
          WHEN 'pages'    THEN COALESCE(SUM(mc.pages_read)::BIGINT, 0)
          WHEN 'minutes'  THEN COALESCE(SUM(mc.minutes_read)::BIGINT, 0)
          WHEN 'sessions' THEN COUNT(DISTINCT mc.id)
          WHEN 'checkins' THEN COUNT(DISTINCT mc.checkin_date)
        END AS contrib
      FROM book_club_members bcm
      LEFT JOIN challenge_manual_checkins mc
        ON mc.user_id      = bcm.user_id
       AND mc.challenge_id = p_challenge_id
       AND mc.checkin_date >= v_starts_at::DATE
       AND mc.checkin_date <  v_ends_at::DATE
      WHERE bcm.club_id = v_club_id
      GROUP BY bcm.user_id
    ),
    totals AS (
      SELECT
        COALESCE(SUM(contrib), 0)                         AS cur,
        (v_goal_value::BIGINT * v_members)                AS tgt,
        COUNT(*) FILTER (WHERE contrib > 0)::INTEGER      AS active
      FROM per_member
    )
    SELECT
      totals.cur::BIGINT,
      totals.tgt::BIGINT,
      LEAST(ROUND(totals.cur::NUMERIC / NULLIF(totals.tgt, 0) * 100, 1), 100),
      (v_ends_at::DATE - CURRENT_DATE)::INTEGER,
      v_members,
      totals.active
    FROM totals;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION club_challenge_collective_progress(UUID) TO authenticated;

-- ── 2. Contribuição percentual do usuário corrente ─────────────────────────────
-- Retorna uma linha com contribution_pct: quanto o usuário contribuiu
-- em relação ao total coletivo (0–100). Retorna vazio se sem progresso.

CREATE OR REPLACE FUNCTION challenge_my_contribution_pct(
  p_challenge_id UUID
)
RETURNS TABLE (
  contribution_pct NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
  v_auto_link  BOOLEAN;
BEGIN
  SELECT club_id, goal_type, starts_at, ends_at, auto_link_sessions
  INTO v_club_id, v_goal_type, v_starts_at, v_ends_at, v_auto_link
  FROM club_challenges WHERE id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  IF v_auto_link THEN
    RETURN QUERY
    WITH club_total AS (
      SELECT GREATEST(
        COALESCE(SUM(
          CASE v_goal_type
            WHEN 'pages'    THEN rs.pages_read
            WHEN 'minutes'  THEN rs.duration_minutes
            WHEN 'sessions' THEN 1
            WHEN 'checkins' THEN 1
          END
        ), 0), 1)::NUMERIC AS total
      FROM book_club_members bcm
      JOIN reading_sessions rs
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
    ),
    my_total AS (
      SELECT COALESCE(SUM(
        CASE v_goal_type
          WHEN 'pages'    THEN rs.pages_read
          WHEN 'minutes'  THEN rs.duration_minutes
          WHEN 'sessions' THEN 1
          WHEN 'checkins' THEN 1
        END
      ), 0)::NUMERIC AS mine
      FROM reading_sessions rs
      WHERE rs.user_id    = auth.uid()
        AND rs.status     = 'finished'
        AND rs.started_at >= v_starts_at
        AND rs.started_at <  v_ends_at
        AND EXISTS (
          SELECT 1 FROM books b
          WHERE b.id = rs.book_id
            AND b.source_club_id = v_club_id
        )
    )
    SELECT ROUND(my_total.mine / club_total.total * 100, 1)
    FROM club_total, my_total
    WHERE my_total.mine > 0;

  ELSE
    RETURN QUERY
    WITH club_total AS (
      SELECT GREATEST(
        COALESCE(SUM(
          CASE v_goal_type
            WHEN 'pages'    THEN mc.pages_read
            WHEN 'minutes'  THEN mc.minutes_read
            WHEN 'sessions' THEN 1
            WHEN 'checkins' THEN 1
          END
        ), 0), 1)::NUMERIC AS total
      FROM challenge_manual_checkins mc
      JOIN book_club_members bcm
        ON bcm.user_id  = mc.user_id
       AND bcm.club_id  = v_club_id
      WHERE mc.challenge_id  = p_challenge_id
        AND mc.checkin_date >= v_starts_at::DATE
        AND mc.checkin_date <  v_ends_at::DATE
    ),
    my_total AS (
      SELECT COALESCE(SUM(
        CASE v_goal_type
          WHEN 'pages'    THEN mc.pages_read
          WHEN 'minutes'  THEN mc.minutes_read
          WHEN 'sessions' THEN 1
          WHEN 'checkins' THEN 1
        END
      ), 0)::NUMERIC AS mine
      FROM challenge_manual_checkins mc
      WHERE mc.challenge_id  = p_challenge_id
        AND mc.user_id       = auth.uid()
        AND mc.checkin_date >= v_starts_at::DATE
        AND mc.checkin_date <  v_ends_at::DATE
    )
    SELECT ROUND(my_total.mine / club_total.total * 100, 1)
    FROM club_total, my_total
    WHERE my_total.mine > 0;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION challenge_my_contribution_pct(UUID) TO authenticated;
