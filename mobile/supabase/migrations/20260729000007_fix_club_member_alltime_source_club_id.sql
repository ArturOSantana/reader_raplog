-- ============================================================
-- READLOG — Fix: club_member_alltime e member_club_profile
-- Bug: a view agregava TODAS as sessões do membro, incluindo
-- leituras de livros de outros clubes, inflando os totais.
-- Correção: filtra por books.source_club_id = bcm.club_id,
-- alinhando com club_ranking e club_challenge_progress.
-- ============================================================

CREATE OR REPLACE VIEW club_member_alltime AS
SELECT
  bcm.club_id,
  bcm.user_id,
  p.name                                                          AS user_name,
  p.avatar_url,
  bcm.joined_at,
  COALESCE(SUM(rs.pages_read), 0)                                AS total_pages_alltime,
  COALESCE(SUM(rs.duration_minutes), 0)                          AS total_minutes_alltime,
  COUNT(DISTINCT rs.id)                                          AS total_sessions_alltime,
  COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))         AS total_days_read,
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
  -- Conta apenas sessões do livro associado a este clube
  AND EXISTS (
    SELECT 1 FROM books b
    WHERE b.id             = rs.book_id
      AND b.source_club_id = bcm.club_id
  )
GROUP BY bcm.club_id, bcm.user_id, p.name, p.avatar_url, bcm.joined_at;

GRANT SELECT ON club_member_alltime TO authenticated;
