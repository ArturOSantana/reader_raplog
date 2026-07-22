-- ============================================================
-- READLOG — Ranking do Clube
-- RPC parametrizado: ranking por período e critério.
-- Cobre: livro_atual | semana | mes | historico
-- Critérios: pages | minutes | sessions | xp
-- ============================================================

CREATE OR REPLACE FUNCTION club_ranking(
  p_club_id  UUID,
  p_period   TEXT DEFAULT 'all',    -- 'current_book' | 'week' | 'month' | 'all'
  p_criteria TEXT DEFAULT 'xp'      -- 'pages' | 'minutes' | 'sessions' | 'xp'
)
RETURNS TABLE (
  position    INTEGER,
  user_id     UUID,
  user_name   TEXT,
  avatar_url  TEXT,
  score       NUMERIC,
  total_pages BIGINT,
  total_minutes BIGINT,
  total_sessions BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_book_id UUID;
  v_from    TIMESTAMPTZ;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Define janela temporal
  v_from := CASE p_period
    WHEN 'week'  THEN DATE_TRUNC('week', NOW())
    WHEN 'month' THEN DATE_TRUNC('month', NOW())
    ELSE NULL
  END;

  -- Para 'current_book' pega o livro atual do clube
  IF p_period = 'current_book' THEN
    SELECT current_book_id, reading_started_at
    INTO v_book_id, v_from
    FROM book_clubs WHERE id = p_club_id;
  END IF;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name                             AS user_name,
      p.avatar_url,
      COALESCE(SUM(rs.pages_read), 0)    AS total_pages,
      COALESCE(SUM(rs.duration_minutes), 0) AS total_minutes,
      COUNT(DISTINCT rs.id)              AS total_sessions
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    LEFT JOIN reading_sessions rs ON
      rs.user_id  = bcm.user_id
      AND rs.status = 'finished'
      AND (v_book_id IS NULL OR rs.book_id = v_book_id)
      AND (v_from    IS NULL OR rs.started_at >= v_from)
    WHERE bcm.club_id = p_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
  ),
  scored AS (
    SELECT *,
      CASE p_criteria
        WHEN 'pages'    THEN total_pages::NUMERIC
        WHEN 'minutes'  THEN total_minutes::NUMERIC
        WHEN 'sessions' THEN total_sessions::NUMERIC
        ELSE -- xp
          (total_pages + total_minutes * 0.5 + total_sessions * 5)::NUMERIC
      END AS score
    FROM raw
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY score DESC, user_name ASC)::INTEGER AS position,
    scored.user_id,
    scored.user_name,
    scored.avatar_url,
    scored.score,
    scored.total_pages,
    scored.total_minutes,
    scored.total_sessions
  FROM scored
  ORDER BY score DESC, user_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_ranking(UUID, TEXT, TEXT) TO authenticated;
