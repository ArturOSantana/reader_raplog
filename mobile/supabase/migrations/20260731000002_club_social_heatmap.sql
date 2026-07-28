-- ============================================================
-- READLOG — Heatmap Social do Clube
-- RPC que agrega a atividade coletiva de leitura do clube
-- por dia, nos últimos N dias. Usado para o "heatmap do clube"
-- que mostra o quanto o grupo leu em cada dia.
-- ============================================================

CREATE OR REPLACE FUNCTION club_social_heatmap(
  p_club_id UUID,
  p_days    INTEGER DEFAULT 30   -- janela de dias (7, 30 ou 90)
)
RETURNS TABLE (
  day          DATE,
  total_pages  BIGINT,
  total_minutes BIGINT,
  active_members BIGINT,   -- membros distintos que leram nesse dia
  intensity    INTEGER      -- 0–4 para renderização visual (como GitHub)
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_max_pages BIGINT;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Gera o resultado sem o campo intensity primeiro para calcular o máximo
  CREATE TEMP TABLE _heatmap_raw ON COMMIT DROP AS
  SELECT
    DATE(rs.started_at AT TIME ZONE 'UTC')  AS day,
    COALESCE(SUM(rs.pages_read), 0)         AS total_pages,
    COALESCE(SUM(rs.duration_minutes), 0)   AS total_minutes,
    COUNT(DISTINCT rs.user_id)              AS active_members
  FROM reading_sessions rs
  JOIN book_club_members bcm ON bcm.user_id = rs.user_id
                             AND bcm.club_id = p_club_id
  WHERE rs.status = 'finished'
    AND rs.started_at >= NOW() - (p_days || ' days')::INTERVAL
  GROUP BY DATE(rs.started_at AT TIME ZONE 'UTC');

  -- Pega o máximo para normalizar a intensidade
  SELECT COALESCE(MAX(total_pages), 1)
  INTO v_max_pages
  FROM _heatmap_raw;

  RETURN QUERY
  -- Garante que todos os dias apareçam, mesmo sem leitura
  WITH calendar AS (
    SELECT generate_series(
      (NOW() - (p_days || ' days')::INTERVAL)::DATE,
      NOW()::DATE,
      '1 day'::INTERVAL
    )::DATE AS day
  )
  SELECT
    c.day,
    COALESCE(r.total_pages, 0)    AS total_pages,
    COALESCE(r.total_minutes, 0)  AS total_minutes,
    COALESCE(r.active_members, 0) AS active_members,
    -- Intensidade 0–4 baseada em quartis do máximo do período
    CASE
      WHEN COALESCE(r.total_pages, 0) = 0                            THEN 0
      WHEN r.total_pages <= v_max_pages * 0.25                       THEN 1
      WHEN r.total_pages <= v_max_pages * 0.50                       THEN 2
      WHEN r.total_pages <= v_max_pages * 0.75                       THEN 3
      ELSE 4
    END AS intensity
  FROM calendar c
  LEFT JOIN _heatmap_raw r ON r.day = c.day
  ORDER BY c.day ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_social_heatmap(UUID, INTEGER) TO authenticated;
