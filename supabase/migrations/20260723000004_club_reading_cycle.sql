-- ============================================================
-- READLOG — Ciclo de Leitura do Clube
-- Adiciona: current_book_status, meta de ritmo, data-alvo,
--           RPC club_reading_progress e "pessoas lendo agora".
-- ============================================================

-- ── 1. Campos de ciclo em book_clubs ─────────────────────────
ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS current_book_status TEXT DEFAULT 'none'
    CHECK (current_book_status IN ('none','voting','chosen','reading','finished')),
  ADD COLUMN IF NOT EXISTS reading_pace_pages_per_day INTEGER,
  ADD COLUMN IF NOT EXISTS reading_target_end_date    DATE,
  ADD COLUMN IF NOT EXISTS reading_started_at         TIMESTAMPTZ;

-- ── 2. RPC: progresso coletivo do livro atual ─────────────────
-- Retorna: total_pages_read, avg_current_page, member_count,
--          percent_complete, members_read_today.
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
  SELECT
    COALESCE(SUM(rs.pages_read), 0)                      AS total_pages_read,
    COALESCE(AVG(rs.end_page), 0)                        AS avg_current_page,
    COUNT(DISTINCT bcm.user_id)                          AS member_count,
    COALESCE(v_total, 0)                                 AS total_pages_book,
    CASE WHEN COALESCE(v_total, 0) > 0
         THEN ROUND(AVG(rs.end_page)::NUMERIC / v_total * 100, 1)
         ELSE 0 END                                      AS percent_complete,
    COUNT(DISTINCT CASE
      WHEN rs.started_at::DATE = CURRENT_DATE THEN rs.user_id
    END)                                                 AS members_read_today
  FROM book_club_members bcm
  LEFT JOIN LATERAL (
    SELECT rs2.user_id, rs2.pages_read, rs2.end_page, rs2.started_at
    FROM reading_sessions rs2
    WHERE rs2.user_id  = bcm.user_id
      AND rs2.book_id  = v_book_id
      AND rs2.status   = 'finished'
    ORDER BY rs2.ended_at DESC
    LIMIT 1
  ) rs ON TRUE
  WHERE bcm.club_id = p_club_id;
END;
$$;

GRANT EXECUTE ON FUNCTION club_reading_progress(UUID) TO authenticated;

-- ── 3. RPC: membros lendo agora ───────────────────────────────
-- Retorna membros com sessão ativa no livro atual do clube.
CREATE OR REPLACE FUNCTION club_reading_now(p_club_id UUID)
RETURNS TABLE (
  user_id     UUID,
  user_name   TEXT,
  avatar_url  TEXT,
  started_at  TIMESTAMPTZ,
  current_page INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_book_id UUID;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT current_book_id INTO v_book_id FROM book_clubs WHERE id = p_club_id;
  IF v_book_id IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    rs.user_id,
    p.name   AS user_name,
    p.avatar_url,
    rs.started_at,
    rs.start_page AS current_page
  FROM reading_sessions rs
  JOIN profiles p ON p.id = rs.user_id
  WHERE rs.book_id = v_book_id
    AND rs.status  = 'active'
    AND is_club_member(p_club_id, rs.user_id)
  ORDER BY rs.started_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_reading_now(UUID) TO authenticated;
