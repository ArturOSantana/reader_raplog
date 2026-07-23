-- ============================================================
-- READLOG — Heatmap de Leitura por Desafio (F-02)
-- Retorna série diária com páginas, minutos e flag de rest day.
-- Consumido pelo ChallengeHeatmapWidget e ChallengeProgressChart.
-- ============================================================

-- ── 1. RPC: dados do heatmap ─────────────────────────────────
CREATE OR REPLACE FUNCTION challenge_heatmap(
  p_challenge_id UUID,
  p_user_id      UUID DEFAULT NULL   -- NULL = o próprio caller
)
RETURNS TABLE (
  day          DATE,
  pages_read   BIGINT,
  minutes_read BIGINT,
  sessions_count BIGINT,
  is_rest_day  BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
  v_target_uid UUID;
BEGIN
  SELECT club_id, starts_at, ends_at
  INTO v_club_id, v_starts_at, v_ends_at
  FROM club_challenges
  WHERE id = p_challenge_id;

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  v_target_uid := COALESCE(p_user_id, auth.uid());

  RETURN QUERY
  SELECT
    d::DATE                                                    AS day,
    COALESCE(SUM(rs.pages_read), 0)                           AS pages_read,
    COALESCE(SUM(rs.duration_minutes), 0)                     AS minutes_read,
    COUNT(rs.id)                                              AS sessions_count,
    EXISTS (
      SELECT 1
      FROM challenge_rest_day_usage rdu
      WHERE rdu.challenge_id = p_challenge_id
        AND rdu.user_id      = v_target_uid
        AND rdu.rest_date    = d::DATE
    )                                                         AS is_rest_day
  FROM generate_series(
    v_starts_at::DATE,
    LEAST(v_ends_at::DATE, CURRENT_DATE),
    '1 day'::INTERVAL
  ) d
  LEFT JOIN reading_sessions rs
    ON rs.user_id    = v_target_uid
   AND rs.status     = 'finished'
   AND DATE(rs.started_at AT TIME ZONE 'UTC') = d::DATE
  GROUP BY d
  ORDER BY d ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION challenge_heatmap(UUID, UUID) TO authenticated;

-- ── 2. RPC: progresso acumulado diário (para o gráfico de linha) ─
-- Versão com SUM acumulado — pronta para fl_chart sem transformação client.
CREATE OR REPLACE FUNCTION challenge_cumulative_progress(
  p_challenge_id UUID,
  p_user_id      UUID DEFAULT NULL
)
RETURNS TABLE (
  day              DATE,
  cumulative_value BIGINT,
  target_value     BIGINT    -- meta linear proporcional ao dia
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_goal_value INTEGER;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
  v_total_days INTEGER;
  v_target_uid UUID;
BEGIN
  SELECT club_id, goal_type, goal_value, starts_at, ends_at
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at
  FROM club_challenges WHERE id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  v_target_uid := COALESCE(p_user_id, auth.uid());
  v_total_days := (v_ends_at::DATE - v_starts_at::DATE) + 1;

  RETURN QUERY
  WITH daily AS (
    SELECT
      d::DATE AS day,
      CASE v_goal_type
        WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
        WHEN 'minutes'  THEN COALESCE(SUM(rs.duration_minutes), 0)
        WHEN 'sessions' THEN COUNT(DISTINCT rs.id)
        WHEN 'checkins' THEN
          CASE WHEN (
            COUNT(rs.id) > 0 OR
            EXISTS (
              SELECT 1 FROM challenge_rest_day_usage rdu
              WHERE rdu.challenge_id = p_challenge_id
                AND rdu.user_id = v_target_uid
                AND rdu.rest_date = d::DATE
            )
          ) THEN 1 ELSE 0 END
      END AS day_value
    FROM generate_series(v_starts_at::DATE, LEAST(v_ends_at::DATE, CURRENT_DATE), '1 day') d
    LEFT JOIN reading_sessions rs
      ON rs.user_id = v_target_uid
     AND rs.status  = 'finished'
     AND DATE(rs.started_at AT TIME ZONE 'UTC') = d::DATE
    GROUP BY d
  )
  SELECT
    daily.day,
    SUM(daily.day_value) OVER (ORDER BY daily.day)::BIGINT        AS cumulative_value,
    ROUND(
      v_goal_value::NUMERIC
      * (daily.day - v_starts_at::DATE + 1)
      / v_total_days
    )::BIGINT                                                      AS target_value
  FROM daily
  ORDER BY daily.day ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION challenge_cumulative_progress(UUID, UUID) TO authenticated;
