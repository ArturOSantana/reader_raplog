-- ============================================================
-- READLOG V3 — Estatísticas Avançadas do Clube
-- ============================================================
-- RPCs que cruzam dados de histórico, sessões e reações para
-- gerar insights como "livro mais polêmico", "autor mais lido",
-- "mês mais produtivo" e "gênero favorito do clube".
-- Dependem de genre/author indexados no catálogo de livros.
-- ============================================================

-- ── 1. Livro mais lido (maior número de páginas totais no clube) ──────────────

CREATE OR REPLACE FUNCTION club_most_read_book(p_club_id UUID)
RETURNS TABLE(
  book_title  TEXT,
  book_author TEXT,
  total_pages BIGINT,
  readers     BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
    SELECT
      cbh.book_title,
      cbh.book_author,
      COALESCE(SUM(rs.pages_read), 0)::BIGINT  AS total_pages,
      COUNT(DISTINCT rs.user_id)::BIGINT        AS readers
    FROM club_book_history cbh
    LEFT JOIN books b ON b.id = cbh.book_id
    LEFT JOIN reading_sessions rs
      ON rs.book_id = cbh.book_id
     AND rs.status  = 'finished'
    WHERE cbh.club_id = p_club_id
      AND cbh.ended_at IS NOT NULL
    GROUP BY cbh.book_title, cbh.book_author
    ORDER BY total_pages DESC
    LIMIT 5;
END;
$$;

GRANT EXECUTE ON FUNCTION club_most_read_book(UUID) TO authenticated;

-- ── 2. Membro mais consistente (maior número de dias únicos com sessão) ───────

CREATE OR REPLACE FUNCTION club_most_consistent_member(p_club_id UUID)
RETURNS TABLE(
  user_id      UUID,
  user_name    TEXT,
  avatar_url   TEXT,
  days_read    BIGINT,
  total_pages  BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
    SELECT
      bcm.user_id,
      p.name,
      p.avatar_url,
      COUNT(DISTINCT DATE(rs.started_at))::BIGINT AS days_read,
      COALESCE(SUM(rs.pages_read), 0)::BIGINT     AS total_pages
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    -- Sessões do livro do clube (via source_club_id)
    JOIN books bk ON bk.source_club_id = p_club_id AND bk.user_id = bcm.user_id
    LEFT JOIN reading_sessions rs
      ON rs.user_id = bcm.user_id
     AND rs.book_id = bk.id
     AND rs.status  = 'finished'
    WHERE bcm.club_id = p_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
    ORDER BY days_read DESC
    LIMIT 5;
END;
$$;

GRANT EXECUTE ON FUNCTION club_most_consistent_member(UUID) TO authenticated;

-- ── 3. Mês mais produtivo do clube ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION club_most_productive_months(p_club_id UUID)
RETURNS TABLE(
  month_label TEXT,
  total_pages BIGINT,
  total_sessions BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
    SELECT
      TO_CHAR(rs.started_at, 'Mon/YYYY')::TEXT AS month_label,
      COALESCE(SUM(rs.pages_read), 0)::BIGINT  AS total_pages,
      COUNT(rs.id)::BIGINT                     AS total_sessions
    FROM book_club_members bcm
    JOIN books bk ON bk.source_club_id = p_club_id AND bk.user_id = bcm.user_id
    JOIN reading_sessions rs
      ON rs.user_id = bcm.user_id
     AND rs.book_id = bk.id
     AND rs.status  = 'finished'
    WHERE bcm.club_id = p_club_id
    GROUP BY TO_CHAR(rs.started_at, 'Mon/YYYY'), DATE_TRUNC('month', rs.started_at)
    ORDER BY DATE_TRUNC('month', rs.started_at) DESC
    LIMIT 12;
END;
$$;

GRANT EXECUTE ON FUNCTION club_most_productive_months(UUID) TO authenticated;

-- ── 4. Livro mais "polêmico" (maior variação de humores registrados) ──────────
-- "Polêmico" = livro cujo conjunto de sessões tem a maior variedade de moods.
-- Requer mood preenchido nas reading_sessions (MVP #5).

CREATE OR REPLACE FUNCTION club_most_controversial_book(p_club_id UUID)
RETURNS TABLE(
  book_title     TEXT,
  book_author    TEXT,
  distinct_moods BIGINT,
  total_sessions BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
    SELECT
      cbh.book_title,
      cbh.book_author,
      COUNT(DISTINCT rs.mood)::BIGINT AS distinct_moods,
      COUNT(rs.id)::BIGINT            AS total_sessions
    FROM club_book_history cbh
    LEFT JOIN books b ON b.id = cbh.book_id
    LEFT JOIN reading_sessions rs
      ON rs.book_id = cbh.book_id
     AND rs.mood IS NOT NULL
     AND rs.status = 'finished'
    WHERE cbh.club_id = p_club_id
      AND cbh.ended_at IS NOT NULL
    GROUP BY cbh.book_title, cbh.book_author
    HAVING COUNT(DISTINCT rs.mood) >= 2
    ORDER BY distinct_moods DESC, total_sessions DESC
    LIMIT 3;
END;
$$;

GRANT EXECUTE ON FUNCTION club_most_controversial_book(UUID) TO authenticated;
