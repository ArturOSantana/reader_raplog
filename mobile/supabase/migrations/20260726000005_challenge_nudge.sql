-- ============================================================
-- READLOG — Nudge de Comparação vs. Média do Clube (F-08)
-- Retorna o delta percentual do usuário em relação à média
-- do clube no desafio. Usado pelo banner de motivação na UI.
-- ============================================================

CREATE OR REPLACE FUNCTION challenge_personal_nudge(p_challenge_id UUID)
RETURNS TABLE (
  my_value         BIGINT,
  club_avg         NUMERIC,
  pct_vs_avg       NUMERIC,   -- positivo = acima da média, negativo = abaixo
  my_rank          INTEGER,
  total_members    BIGINT,
  goal_value       INTEGER,
  my_pct_complete  NUMERIC    -- 0–100
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_value INTEGER;
BEGIN
  SELECT club_id, goal_value
  INTO v_club_id, v_goal_value
  FROM club_challenges WHERE id = p_challenge_id;

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Desafio não encontrado';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  WITH progress AS (
    SELECT
      cp.user_id,
      cp.current_value,
      cp.rank,
      cp.pct_complete
    FROM club_challenge_progress(p_challenge_id) cp
  ),
  agg AS (
    SELECT
      ROUND(AVG(current_value), 1)  AS avg_value,
      COUNT(*)                      AS total_members
    FROM progress
  )
  SELECT
    COALESCE(MAX(p.current_value) FILTER (WHERE p.user_id = auth.uid()), 0)  AS my_value,
    agg.avg_value                                                              AS club_avg,
    ROUND(
      (COALESCE(MAX(p.current_value) FILTER (WHERE p.user_id = auth.uid()), 0)
       - agg.avg_value)
      / NULLIF(agg.avg_value, 0) * 100
    , 1)                                                                      AS pct_vs_avg,
    MAX(p.rank) FILTER (WHERE p.user_id = auth.uid())                        AS my_rank,
    agg.total_members,
    v_goal_value                                                              AS goal_value,
    COALESCE(MAX(p.pct_complete) FILTER (WHERE p.user_id = auth.uid()), 0)  AS my_pct_complete
  FROM progress p
  CROSS JOIN agg
  GROUP BY agg.avg_value, agg.total_members;
END;
$$;

GRANT EXECUTE ON FUNCTION challenge_personal_nudge(UUID) TO authenticated;
