-- ============================================================
-- READLOG — Métricas Coletivas do Clube ("Vocês leram")
-- RPC que retorna as estatísticas agregadas do clube inteiro,
-- com a contribuição percentual do usuário atual.
-- Cria o senso de pertencimento: "você faz parte disto".
-- ============================================================

CREATE OR REPLACE FUNCTION club_collective_stats(p_club_id UUID)
RETURNS TABLE (
  -- Totais históricos do clube
  total_pages         BIGINT,
  total_minutes       BIGINT,
  total_sessions      BIGINT,
  total_books_read    BIGINT,   -- sessões com status finished_book no feed
  total_members       BIGINT,
  active_members_30d  BIGINT,   -- membros que leram nos últimos 30 dias

  -- Contribuição do usuário atual (percentual)
  my_pages_pct        NUMERIC,  -- 0–100
  my_minutes_pct      NUMERIC,

  -- Marcos formatados para exibição
  pages_formatted     TEXT,     -- "34.282" ou "1,2 mil"
  minutes_to_hours    INTEGER   -- total em horas (para "X horas de leitura")
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_pages   BIGINT;
  v_total_minutes BIGINT;
  v_total_sess    BIGINT;
  v_total_books   BIGINT;
  v_total_members BIGINT;
  v_active_30d    BIGINT;
  v_my_pages      BIGINT;
  v_my_minutes    BIGINT;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Totais do clube via reading_sessions de todos os membros
  SELECT
    COALESCE(SUM(rs.pages_read), 0),
    COALESCE(SUM(rs.duration_minutes), 0),
    COUNT(DISTINCT rs.id),
    COUNT(DISTINCT CASE WHEN rs.pages_read > 0 THEN rs.book_id END)
  INTO v_total_pages, v_total_minutes, v_total_sess, v_total_books
  FROM reading_sessions rs
  JOIN book_club_members bcm ON bcm.user_id = rs.user_id
                             AND bcm.club_id = p_club_id
  WHERE rs.status = 'finished';

  -- Total de membros e membros ativos nos últimos 30 dias
  SELECT
    COUNT(DISTINCT bcm.user_id),
    COUNT(DISTINCT CASE
      WHEN rs.started_at >= NOW() - INTERVAL '30 days' THEN bcm.user_id
    END)
  INTO v_total_members, v_active_30d
  FROM book_club_members bcm
  LEFT JOIN reading_sessions rs ON rs.user_id = rs.user_id
                                AND rs.status  = 'finished'
  WHERE bcm.club_id = p_club_id;

  -- Contribuição do usuário atual
  SELECT
    COALESCE(SUM(rs.pages_read), 0),
    COALESCE(SUM(rs.duration_minutes), 0)
  INTO v_my_pages, v_my_minutes
  FROM reading_sessions rs
  JOIN book_club_members bcm ON bcm.user_id = rs.user_id
                             AND bcm.club_id = p_club_id
  WHERE rs.status   = 'finished'
    AND rs.user_id  = auth.uid();

  RETURN QUERY SELECT
    v_total_pages,
    v_total_minutes,
    v_total_sess,
    v_total_books,
    v_total_members,
    v_active_30d,
    CASE WHEN v_total_pages > 0
         THEN ROUND(v_my_pages::NUMERIC / v_total_pages * 100, 1)
         ELSE 0 END,
    CASE WHEN v_total_minutes > 0
         THEN ROUND(v_my_minutes::NUMERIC / v_total_minutes * 100, 1)
         ELSE 0 END,
    -- Formata em milhar (ex: "34.282")
    TO_CHAR(v_total_pages, 'FM999G999G999'),
    (v_total_minutes / 60)::INTEGER;
END;
$$;

GRANT EXECUTE ON FUNCTION club_collective_stats(UUID) TO authenticated;
