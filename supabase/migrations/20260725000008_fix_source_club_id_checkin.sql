-- ============================================================
-- READLOG — Correções do check-in automático por source_club_id
--
-- Problema: o trigger, streak e ranking identificavam o clube
-- via bc.current_book_id (livro atual do clube), mas a spec
-- define que o vínculo correto é books.source_club_id —
-- assim um membro que adicionou o livro do clube na própria
-- biblioteca tem check-in automático em TODA sessão daquele
-- livro, mesmo que o clube já tenha avançado de ciclo.
--
-- Mudanças:
-- 1. auto_checkin_after_session — usa source_club_id
-- 2. calculate_club_streak      — filtra por source_club_id
-- 3. club_ranking               — filtra por source_club_id
-- 4. club_challenge_progress    — filtra por source_club_id
-- ============================================================

-- ── 1. Trigger: check-in automático ──────────────────────────
-- Antes: localizava o clube pelo current_book_id.
-- Agora: usa books.source_club_id do livro lido.
-- Mantém a guarda de segurança: o clube precisa existir e o
-- usuário precisa ser membro.
CREATE OR REPLACE FUNCTION auto_checkin_after_session()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  -- Só dispara ao finalizar (transição para 'finished')
  IF NEW.status != 'finished' OR OLD.status = 'finished' THEN
    RETURN NEW;
  END IF;

  -- Descobre o clube pelo source_club_id do livro lido
  SELECT b.source_club_id INTO v_club_id
  FROM books b
  WHERE b.id = NEW.book_id
    AND b.source_club_id IS NOT NULL;

  IF v_club_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Confirma que o usuário ainda é membro do clube
  IF NOT is_club_member(v_club_id, NEW.user_id) THEN
    RETURN NEW;
  END IF;

  -- Evita duplicata: já existe post desta sessão?
  IF EXISTS (
    SELECT 1 FROM social_feed sf
    WHERE sf.user_id  = NEW.user_id
      AND sf.club_id  = v_club_id
      AND sf.event_type = 'reading_session'
      AND sf.created_at >= NEW.started_at
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO social_feed (
    user_id, event_type, club_id,
    book_title, pages_read, current_page,
    session_minutes, streak_days
  )
  SELECT
    NEW.user_id,
    'reading_session',
    v_club_id,
    b.title,
    NEW.pages_read,
    NEW.end_page,
    NEW.duration_minutes,
    calculate_streak(NEW.user_id)
  FROM books b
  WHERE b.id = NEW.book_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_checkin ON reading_sessions;
CREATE TRIGGER trg_auto_checkin
  AFTER UPDATE OF status ON reading_sessions
  FOR EACH ROW EXECUTE FUNCTION auto_checkin_after_session();

GRANT EXECUTE ON FUNCTION auto_checkin_after_session() TO authenticated;

-- ── 2. Ofensiva coletiva por source_club_id ───────────────────
-- Antes: contava sessões de QUALQUER livro de membros do clube.
-- Agora: conta apenas sessões de livros com source_club_id = clube.
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
    JOIN books b ON b.id = rs.book_id
    WHERE b.source_club_id = p_club_id
      AND rs.status        = 'finished'
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

-- ── 3. Ranking por source_club_id ─────────────────────────────
-- Antes: 'current_book' filtrava por bc.current_book_id e demais
-- períodos contavam qualquer sessão de qualquer livro do membro.
-- Agora: todos os períodos filtram por books.source_club_id = clube,
-- garantindo que só sessões do livro do clube contem.
-- O período 'current_book' mantém o filtro adicional de
-- reading_started_at para contar apenas o ciclo em andamento.
CREATE OR REPLACE FUNCTION club_ranking(
  p_club_id  UUID,
  p_period   TEXT DEFAULT 'all',    -- 'current_book' | 'week' | 'month' | 'all'
  p_criteria TEXT DEFAULT 'xp'      -- 'pages' | 'minutes' | 'sessions' | 'xp'
)
RETURNS TABLE (
  rank           INTEGER,
  user_id        UUID,
  user_name      TEXT,
  avatar_url     TEXT,
  score          NUMERIC,
  total_pages    BIGINT,
  total_minutes  BIGINT,
  total_sessions BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_from TIMESTAMPTZ;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Define janela temporal
  v_from := CASE p_period
    WHEN 'week'         THEN DATE_TRUNC('week', NOW())
    WHEN 'month'        THEN DATE_TRUNC('month', NOW())
    WHEN 'current_book' THEN (SELECT reading_started_at FROM book_clubs WHERE id = p_club_id)
    ELSE NULL
  END;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name                                AS user_name,
      p.avatar_url,
      COALESCE(SUM(rs.pages_read), 0)       AS total_pages,
      COALESCE(SUM(rs.duration_minutes), 0) AS total_minutes,
      COUNT(DISTINCT rs.id)                 AS total_sessions
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    LEFT JOIN reading_sessions rs ON
      rs.user_id  = bcm.user_id
      AND rs.status = 'finished'
      AND EXISTS (
        SELECT 1 FROM books b
        WHERE b.id = rs.book_id
          AND b.source_club_id = p_club_id
      )
      AND (v_from IS NULL OR rs.started_at >= v_from)
    WHERE bcm.club_id = p_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
  ),
  scored AS (
    SELECT *,
      CASE p_criteria
        WHEN 'pages'    THEN total_pages::NUMERIC
        WHEN 'minutes'  THEN total_minutes::NUMERIC
        WHEN 'sessions' THEN total_sessions::NUMERIC
        ELSE -- xp
          (total_pages + total_minutes * 0.5 + total_sessions * 5)::NUMERIC
      END AS score
    FROM raw
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY score DESC, user_name ASC)::INTEGER AS rank,
    scored.user_id,
    scored.user_name,
    scored.avatar_url,
    scored.score,
    scored.total_pages,
    scored.total_minutes,
    scored.total_sessions
  FROM scored
  ORDER BY score DESC, user_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_ranking(UUID, TEXT, TEXT) TO authenticated;

-- ── 4. Progresso do desafio por source_club_id ───────────────
-- Antes: contava qualquer sessão do membro no período.
-- Agora: conta apenas sessões de livros com source_club_id = clube do desafio.
CREATE OR REPLACE FUNCTION club_challenge_progress(p_challenge_id UUID)
RETURNS TABLE (
  user_id       UUID,
  user_name     TEXT,
  avatar_url    TEXT,
  current_value BIGINT,
  goal_value    INTEGER,
  pct_complete  NUMERIC,
  rank          INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_goal_value INTEGER;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
BEGIN
  SELECT club_id, goal_type, c.goal_value, starts_at, ends_at
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at
  FROM club_challenges c WHERE c.id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name        AS user_name,
      p.avatar_url,
      CASE v_goal_type
        WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
        WHEN 'minutes'  THEN COALESCE(SUM(rs.duration_minutes), 0)
        WHEN 'sessions' THEN COUNT(DISTINCT rs.id)
        WHEN 'checkins' THEN COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))
      END AS current_value
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    LEFT JOIN reading_sessions rs
      ON rs.user_id    = bcm.user_id
     AND rs.status     = 'finished'
     AND rs.started_at >= v_starts_at
     AND rs.started_at <  v_ends_at
     AND EXISTS (
       SELECT 1 FROM books b
       WHERE b.id = rs.book_id
         AND b.source_club_id = v_club_id
     )
    WHERE bcm.club_id = v_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
  )
  SELECT
    raw.user_id,
    raw.user_name,
    raw.avatar_url,
    raw.current_value,
    v_goal_value,
    LEAST(ROUND(raw.current_value::NUMERIC / v_goal_value * 100, 1), 100) AS pct_complete,
    ROW_NUMBER() OVER (ORDER BY raw.current_value DESC, raw.user_name ASC)::INTEGER AS rank
  FROM raw
  ORDER BY raw.current_value DESC, raw.user_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_challenge_progress(UUID) TO authenticated;
