-- ============================================================
-- READLOG — Ofensiva Coletiva + Estatísticas do Clube
-- Adiciona: calculate_club_streak(club_id) e view club_stats.
-- ============================================================

-- ── 1. Ofensiva coletiva ──────────────────────────────────────
-- O clube mantém ofensiva enquanto pelo menos 1 membro ler por dia.
CREATE OR REPLACE FUNCTION calculate_club_streak(p_club_id UUID)
RETURNS INTEGER LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_streak  INTEGER := 0;
  v_cursor  DATE    := CURRENT_DATE;
  v_date    DATE;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  FOR v_date IN
    SELECT DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC')
    FROM reading_sessions rs
    JOIN book_club_members bcm ON bcm.user_id = rs.user_id
    WHERE bcm.club_id = p_club_id
      AND rs.status   = 'finished'
    ORDER BY 1 DESC
  LOOP
    IF v_date >= v_cursor - INTERVAL '1 day' THEN
      v_streak := v_streak + 1;
      v_cursor  := v_date;
    ELSE
      EXIT;
    END IF;
  END LOOP;

  RETURN v_streak;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_club_streak(UUID) TO authenticated;

-- ── 2. View: estatísticas globais do clube ───────────────────
CREATE OR REPLACE VIEW club_stats AS
SELECT
  bcm.club_id,
  COUNT(DISTINCT bcm.user_id)                          AS member_count,
  COUNT(DISTINCT rs.id)                                AS total_sessions,
  COALESCE(SUM(rs.pages_read), 0)                      AS total_pages,
  COALESCE(SUM(rs.duration_minutes), 0)                AS total_minutes,
  COALESCE(SUM(rs.duration_minutes) / 60.0, 0)         AS total_hours,
  COUNT(DISTINCT CASE
    WHEN b.status = 'read' THEN b.id
  END)                                                 AS books_finished
FROM book_club_members bcm
LEFT JOIN reading_sessions rs
  ON rs.user_id = bcm.user_id AND rs.status = 'finished'
LEFT JOIN books b
  ON b.id = rs.book_id AND b.user_id = bcm.user_id
GROUP BY bcm.club_id;

-- ── 3. View: estatísticas por membro dentro do clube ─────────
-- Base para o ranking — calcula XP simplificado:
--   páginas × 1 pt  +  minutos × 0.5 pt  +  sessões × 5 pt
CREATE OR REPLACE VIEW club_member_stats AS
SELECT
  bcm.club_id,
  bcm.user_id,
  p.name                                               AS user_name,
  p.avatar_url,
  bcm.joined_at,
  COALESCE(SUM(rs.pages_read), 0)                      AS total_pages,
  COALESCE(SUM(rs.duration_minutes), 0)                AS total_minutes,
  COUNT(DISTINCT rs.id)                                AS total_sessions,
  -- XP = páginas + minutos*0.5 + sessões*5
  COALESCE(
    SUM(rs.pages_read)
    + SUM(rs.duration_minutes) * 0.5
    + COUNT(DISTINCT rs.id) * 5,
    0
  )::INTEGER                                           AS xp_total
FROM book_club_members bcm
JOIN profiles p ON p.id = bcm.user_id
LEFT JOIN reading_sessions rs
  ON rs.user_id = bcm.user_id AND rs.status = 'finished'
GROUP BY bcm.club_id, bcm.user_id, p.name, p.avatar_url, bcm.joined_at;
