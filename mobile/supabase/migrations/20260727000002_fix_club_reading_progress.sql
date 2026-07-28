-- ============================================================
-- READLOG — Fix: club_reading_progress
-- Bug: LATERAL JOIN com LIMIT 1 usava só a última sessão de
-- cada membro, fazendo SUM(pages_read) ignorar sessões anteriores.
-- Correção: separa a agregação total (todas as sessões) da
-- página atual (última sessão), usando dois LEFT JOINs.
-- ============================================================

CREATE OR REPLACE FUNCTION club_reading_progress(p_club_id UUID)
RETURNS TABLE (
  total_pages_read     BIGINT,
  avg_current_page     NUMERIC,
  member_count         BIGINT,
  total_pages_book     INTEGER,
  percent_complete     NUMERIC,
  members_read_today   BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_book_id UUID;
  v_total   INTEGER;
BEGIN
  -- Garante que o caller é membro
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT current_book_id INTO v_book_id FROM book_clubs WHERE id = p_club_id;
  IF v_book_id IS NULL THEN
    RETURN QUERY SELECT 0::BIGINT, 0::NUMERIC, 0::BIGINT, 0, 0::NUMERIC, 0::BIGINT;
    RETURN;
  END IF;

  SELECT total_pages INTO v_total FROM books WHERE id = v_book_id LIMIT 1;

  RETURN QUERY
  WITH
  -- Todas as sessões finalizadas no livro: soma páginas e detecta leitura hoje
  all_sessions AS (
    SELECT
      rs.user_id,
      SUM(rs.pages_read)                                           AS total_pages,
      MAX(CASE WHEN rs.started_at::DATE = CURRENT_DATE THEN 1 ELSE 0 END) AS read_today
    FROM reading_sessions rs
    WHERE rs.book_id = v_book_id
      AND rs.status  = 'finished'
      AND is_club_member(p_club_id, rs.user_id)
    GROUP BY rs.user_id
  ),
  -- Última sessão de cada membro: fornece a página atual (end_page)
  last_session AS (
    SELECT DISTINCT ON (rs.user_id)
      rs.user_id,
      rs.end_page
    FROM reading_sessions rs
    WHERE rs.book_id = v_book_id
      AND rs.status  = 'finished'
      AND is_club_member(p_club_id, rs.user_id)
    ORDER BY rs.user_id, rs.ended_at DESC
  )
  SELECT
    COALESCE(SUM(a.total_pages), 0)                              AS total_pages_read,
    COALESCE(AVG(ls.end_page), 0)                                AS avg_current_page,
    COUNT(DISTINCT bcm.user_id)                                  AS member_count,
    COALESCE(v_total, 0)                                         AS total_pages_book,
    CASE WHEN COALESCE(v_total, 0) > 0
         THEN ROUND(AVG(ls.end_page)::NUMERIC / v_total * 100, 1)
         ELSE 0 END                                              AS percent_complete,
    COALESCE(SUM(a.read_today), 0)                               AS members_read_today
  FROM book_club_members bcm
  LEFT JOIN all_sessions  a  ON a.user_id  = bcm.user_id
  LEFT JOIN last_session  ls ON ls.user_id = bcm.user_id
  WHERE bcm.club_id = p_club_id;
END;
$$;

GRANT EXECUTE ON FUNCTION club_reading_progress(UUID) TO authenticated;
