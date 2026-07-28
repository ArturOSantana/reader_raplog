-- ============================================================
-- READLOG — Estatísticas Históricas por Membro no Clube (F-09)
-- View all-time: total de páginas, sessões, dias lidos e
-- desafios concluídos. Base para a tela de perfil do clube.
-- ============================================================

-- ── 1. View: stats all-time por membro ───────────────────────
CREATE OR REPLACE VIEW club_member_alltime AS
SELECT
  bcm.club_id,
  bcm.user_id,
  p.name                                                          AS user_name,
  p.avatar_url,
  bcm.joined_at,
  -- Totais históricos de leitura (todas as sessões, sem filtro de período)
  COALESCE(SUM(rs.pages_read), 0)                                AS total_pages_alltime,
  COALESCE(SUM(rs.duration_minutes), 0)                          AS total_minutes_alltime,
  COUNT(DISTINCT rs.id)                                          AS total_sessions_alltime,
  -- Dias distintos com pelo menos 1 sessão concluída
  COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))         AS total_days_read,
  -- Média de páginas por dia de leitura
  CASE
    WHEN COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC')) > 0
    THEN ROUND(
      COALESCE(SUM(rs.pages_read), 0)::NUMERIC
      / COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))
    , 1)
    ELSE 0
  END                                                            AS avg_pages_per_day
FROM book_club_members bcm
JOIN profiles p ON p.id = bcm.user_id
LEFT JOIN reading_sessions rs
  ON rs.user_id = bcm.user_id
  AND rs.status = 'finished'
GROUP BY bcm.club_id, bcm.user_id, p.name, p.avatar_url, bcm.joined_at;

GRANT SELECT ON club_member_alltime TO authenticated;

-- ── 2. RPC: perfil completo do membro no clube ───────────────
-- Agrega all-time stats + histórico de desafios participados.
CREATE OR REPLACE FUNCTION member_club_profile(
  p_club_id UUID,
  p_user_id UUID DEFAULT NULL   -- NULL = o próprio caller
)
RETURNS TABLE (
  user_id               UUID,
  user_name             TEXT,
  avatar_url            TEXT,
  joined_at             TIMESTAMPTZ,
  total_pages_alltime   BIGINT,
  total_minutes_alltime BIGINT,
  total_sessions        BIGINT,
  total_days_read       BIGINT,
  avg_pages_per_day     NUMERIC,
  challenges_completed  BIGINT,
  challenges_total      BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_target_uid UUID;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  v_target_uid := COALESCE(p_user_id, auth.uid());

  RETURN QUERY
  SELECT
    cma.user_id,
    cma.user_name,
    cma.avatar_url,
    cma.joined_at,
    cma.total_pages_alltime,
    cma.total_minutes_alltime,
    cma.total_sessions_alltime,
    cma.total_days_read,
    cma.avg_pages_per_day,
    -- Desafios em que o membro atingiu 100% da meta
    (
      SELECT COUNT(*)
      FROM challenge_results cr
      JOIN club_challenges cc ON cc.id = cr.challenge_id
      WHERE cc.club_id = p_club_id
        AND (
          cr.first_user_id  = v_target_uid
          OR cr.second_user_id = v_target_uid
          OR cr.third_user_id  = v_target_uid
        )
    )::BIGINT                                                       AS challenges_completed,
    -- Total de desafios do clube que estavam ativos enquanto o membro era membro
    (
      SELECT COUNT(*)
      FROM club_challenges cc
      WHERE cc.club_id = p_club_id
        AND cc.starts_at >= cma.joined_at
    )::BIGINT                                                       AS challenges_total
  FROM club_member_alltime cma
  WHERE cma.club_id = p_club_id
    AND cma.user_id = v_target_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION member_club_profile(UUID, UUID) TO authenticated;
