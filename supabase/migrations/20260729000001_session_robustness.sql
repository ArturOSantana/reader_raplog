-- ============================================================
-- READLOG — Session robustness: duration cap + orphan cleanup
--
-- 1. Cap de 3h nas métricas de desafio, streak e ranking
--    Sessões muito longas (esquecidas abertas) não devem inflar
--    as estatísticas da gamificação. O campo duration_minutes
--    bruto é preservado para estatísticas pessoais; a função
--    effective_duration_minutes() aplica o cap apenas quando
--    necessário.
--
-- 2. Auto-cancelamento de sessões órfãs
--    Qualquer sessão com status = 'active' iniciada há mais de
--    12 horas é automaticamente cancelada pelo banco, evitando
--    lixo permanente nos dados.
-- ============================================================

-- ── 1. Função auxiliar: duração efetiva com cap ─────────────
-- Retorna o menor valor entre duration_minutes e 180 (3h).
-- Usada pelos RPCs de streak, ranking e desafio para não
-- inflar métricas por sessões esquecidas.
CREATE OR REPLACE FUNCTION effective_duration_minutes(p_minutes INTEGER)
RETURNS INTEGER
LANGUAGE sql IMMUTABLE AS $$
  SELECT LEAST(COALESCE(p_minutes, 0), 180);
$$;

GRANT EXECUTE ON FUNCTION effective_duration_minutes(INTEGER) TO authenticated;

-- ── 2. Recalcula XP e ranking com cap ────────────────────────
-- Atualiza club_member_stats para usar effective_duration_minutes.
CREATE OR REPLACE VIEW club_member_stats AS
SELECT
  bcm.club_id,
  bcm.user_id,
  p.name                                               AS user_name,
  p.avatar_url,
  bcm.joined_at,
  COALESCE(SUM(rs.pages_read), 0)                      AS total_pages,
  COALESCE(SUM(effective_duration_minutes(rs.duration_minutes)), 0) AS total_minutes,
  COUNT(DISTINCT rs.id)                                AS total_sessions,
  -- XP = páginas + minutos_efetivos*0.5 + sessões*5
  COALESCE(
    SUM(rs.pages_read)
    + SUM(effective_duration_minutes(rs.duration_minutes)) * 0.5
    + COUNT(DISTINCT rs.id) * 5,
    0
  )::INTEGER                                           AS xp_total
FROM book_club_members bcm
JOIN profiles p ON p.id = bcm.user_id
LEFT JOIN reading_sessions rs
  ON rs.user_id = bcm.user_id AND rs.status = 'finished'
GROUP BY bcm.club_id, bcm.user_id, p.name, p.avatar_url, bcm.joined_at;

-- ── 3. Ranking com cap de duração ────────────────────────────
CREATE OR REPLACE FUNCTION club_ranking(
  p_club_id  UUID,
  p_period   TEXT DEFAULT 'all',
  p_criteria TEXT DEFAULT 'xp'
)
RETURNS TABLE (
  rank           INTEGER,
  user_id        UUID,
  user_name      TEXT,
  avatar_url     TEXT,
  score          NUMERIC,
  total_pages    BIGINT,
  total_minutes  BIGINT,
  total_sessions BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_from TIMESTAMPTZ;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  v_from := CASE p_period
    WHEN 'week'         THEN DATE_TRUNC('week', NOW())
    WHEN 'month'        THEN DATE_TRUNC('month', NOW())
    WHEN 'current_book' THEN (SELECT reading_started_at FROM book_clubs WHERE id = p_club_id)
    ELSE NULL
  END;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name                                                        AS user_name,
      p.avatar_url,
      COALESCE(SUM(rs.pages_read), 0)                               AS total_pages,
      COALESCE(SUM(effective_duration_minutes(rs.duration_minutes)), 0) AS total_minutes,
      COUNT(DISTINCT rs.id)                                         AS total_sessions
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    LEFT JOIN reading_sessions rs ON
      rs.user_id  = bcm.user_id
      AND rs.status = 'finished'
      AND EXISTS (
        SELECT 1 FROM books b
        WHERE b.id = rs.book_id
          AND b.source_club_id = p_club_id
      )
      AND (v_from IS NULL OR rs.started_at >= v_from)
    WHERE bcm.club_id = p_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
  ),
  scored AS (
    SELECT *,
      CASE p_criteria
        WHEN 'pages'    THEN total_pages::NUMERIC
        WHEN 'minutes'  THEN total_minutes::NUMERIC
        WHEN 'sessions' THEN total_sessions::NUMERIC
        ELSE
          (total_pages + total_minutes * 0.5 + total_sessions * 5)::NUMERIC
      END AS score
    FROM raw
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY score DESC, user_name ASC)::INTEGER AS rank,
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

-- ── 4. Progresso do desafio com cap de duração ───────────────
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
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_goal_value INTEGER;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
BEGIN
  SELECT club_id, goal_type, c.goal_value, starts_at, ends_at
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at
  FROM club_challenges c WHERE c.id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name        AS user_name,
      p.avatar_url,
      CASE v_goal_type
        -- minutos usa cap de 3h por sessão
        WHEN 'minutes'  THEN COALESCE(SUM(effective_duration_minutes(rs.duration_minutes)), 0)
        WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
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
END;
$$;

GRANT EXECUTE ON FUNCTION club_challenge_progress(UUID) TO authenticated;

-- ── 5. Auto-cancelamento de sessões órfãs (> 12h ativas) ────
-- Executado como função agendada pelo pg_cron ou chamado manualmente.
-- Cancela sessões que ficaram 'active' por mais de 12 horas,
-- evitando que dados ruins contaminem streak e ranking.
CREATE OR REPLACE FUNCTION cancel_orphan_sessions()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count INTEGER;
BEGIN
  WITH cancelled AS (
    UPDATE reading_sessions
    SET status = 'cancelled'
    WHERE status = 'active'
      AND started_at < NOW() - INTERVAL '12 hours'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_count FROM cancelled;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_orphan_sessions() TO authenticated;

-- Agenda a limpeza para rodar a cada hora (requer pg_cron habilitado no projeto)
-- Se pg_cron não estiver disponível, a função pode ser chamada manualmente
-- ou via Edge Function com cron schedule.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'cancel-orphan-sessions',
      '0 * * * *',
      'SELECT cancel_orphan_sessions()'
    );
  END IF;
END $$;
