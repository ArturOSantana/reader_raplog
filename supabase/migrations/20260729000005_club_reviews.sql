-- ============================================================
-- READLOG — Resenhas Construtivas no Feed (Seção 8)
-- Diferente do mini_review (por sessão/diário).
-- A resenha é o fechamento de um ciclo de leitura completo.
-- ============================================================

-- ── 1. Tabela principal ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_reviews (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id          UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  -- Vincula ao ciclo específico, não ao título genérico.
  -- Se o mesmo livro for relido, cada ciclo tem suas próprias resenhas.
  book_history_id  UUID        NOT NULL REFERENCES club_book_history(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating           SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
  what_worked      TEXT        CHECK (char_length(what_worked) <= 300),
  what_didnt       TEXT        CHECK (char_length(what_didnt) <= 300),
  would_recommend  TEXT        NOT NULL
                     CHECK (would_recommend IN ('yes', 'no', 'with_reservations')),
  spoiler_level    TEXT        NOT NULL DEFAULT 'none'
                     CHECK (spoiler_level IN ('none', 'partial', 'full')),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ,
  -- 1 resenha por membro por ciclo de livro. Upsert no submitReview.
  UNIQUE (club_id, book_history_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_club_reviews_history
  ON club_reviews(book_history_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_club_reviews_club
  ON club_reviews(club_id, created_at DESC);

ALTER TABLE club_reviews ENABLE ROW LEVEL SECURITY;

-- SELECT: membros do clube
CREATE POLICY "reviews: member select"
  ON club_reviews FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- INSERT: membro do clube E com ao menos 1 sessão finalizada no ciclo
CREATE POLICY "reviews: member insert"
  ON club_reviews FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND is_club_member(club_id, auth.uid())
    AND EXISTS (
      SELECT 1
      FROM reading_sessions rs
      JOIN books b ON b.id = rs.book_id
      JOIN club_book_history cbh ON cbh.id = book_history_id
      WHERE rs.user_id = auth.uid()
        AND rs.status  = 'finished'
        AND b.id       = cbh.book_id
    )
  );

-- UPDATE: somente o autor, e somente enquanto o histórico não estiver arquivado
CREATE POLICY "reviews: author update"
  ON club_reviews FOR UPDATE
  USING (
    auth.uid() = user_id
    AND NOT EXISTS (
      SELECT 1 FROM club_book_history cbh
      WHERE cbh.id = book_history_id
        AND cbh.ended_at IS NOT NULL
    )
  );

-- DELETE: autor ou manager
CREATE POLICY "reviews: author or manager delete"
  ON club_reviews FOR DELETE
  USING (
    auth.uid() = user_id
    OR is_club_manager(club_id, auth.uid())
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_reviews TO authenticated;

-- ── 2. RPC: submit (upsert) ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION submit_club_review(
  p_club_id        UUID,
  p_book_history_id UUID,
  p_rating         SMALLINT,
  p_what_worked    TEXT     DEFAULT NULL,
  p_what_didnt     TEXT     DEFAULT NULL,
  p_would_recommend TEXT    DEFAULT 'yes',
  p_spoiler_level  TEXT     DEFAULT 'none'
)
RETURNS club_reviews
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row club_reviews;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  INSERT INTO club_reviews (
    club_id, book_history_id, user_id,
    rating, what_worked, what_didnt,
    would_recommend, spoiler_level
  )
  VALUES (
    p_club_id, p_book_history_id, auth.uid(),
    p_rating, p_what_worked, p_what_didnt,
    p_would_recommend, p_spoiler_level
  )
  ON CONFLICT (club_id, book_history_id, user_id) DO UPDATE SET
    rating           = EXCLUDED.rating,
    what_worked      = EXCLUDED.what_worked,
    what_didnt       = EXCLUDED.what_didnt,
    would_recommend  = EXCLUDED.would_recommend,
    spoiler_level    = EXCLUDED.spoiler_level,
    updated_at       = NOW()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_club_review(UUID, UUID, SMALLINT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ── 3. RPC: listar resenhas de um ciclo ──────────────────────────────────────

CREATE OR REPLACE FUNCTION fetch_book_reviews(p_book_history_id UUID)
RETURNS TABLE (
  id               UUID,
  club_id          UUID,
  book_history_id  UUID,
  user_id          UUID,
  user_name        TEXT,
  avatar_url       TEXT,
  rating           SMALLINT,
  what_worked      TEXT,
  what_didnt       TEXT,
  would_recommend  TEXT,
  spoiler_level    TEXT,
  avg_rating       NUMERIC,
  created_at       TIMESTAMPTZ,
  updated_at       TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  SELECT club_id INTO v_club_id
  FROM club_book_history WHERE id = p_book_history_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    r.id, r.club_id, r.book_history_id, r.user_id,
    p.name          AS user_name,
    p.avatar_url,
    r.rating,
    r.what_worked,
    r.what_didnt,
    r.would_recommend,
    r.spoiler_level,
    AVG(r.rating) OVER ()::NUMERIC AS avg_rating,
    r.created_at,
    r.updated_at
  FROM club_reviews r
  JOIN profiles p ON p.id = r.user_id
  WHERE r.book_history_id = p_book_history_id
  ORDER BY r.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION fetch_book_reviews(UUID) TO authenticated;

-- ── 4. RPC: estatísticas de resenhas do clube ─────────────────────────────────
-- Alimenta "livro mais controverso" com variância de rating real.

CREATE OR REPLACE FUNCTION fetch_club_review_stats(p_club_id UUID)
RETURNS TABLE (
  book_history_id  UUID,
  book_title       TEXT,
  review_count     BIGINT,
  avg_rating       NUMERIC,
  rating_stddev    NUMERIC   -- alta stddev = livro controverso
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    r.book_history_id,
    cbh.book_title,
    COUNT(*)                          AS review_count,
    ROUND(AVG(r.rating)::NUMERIC, 2)  AS avg_rating,
    ROUND(STDDEV(r.rating)::NUMERIC, 2) AS rating_stddev
  FROM club_reviews r
  JOIN club_book_history cbh ON cbh.id = r.book_history_id
  WHERE r.club_id = p_club_id
  GROUP BY r.book_history_id, cbh.book_title
  ORDER BY rating_stddev DESC NULLS LAST, avg_rating DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION fetch_club_review_stats(UUID) TO authenticated;

-- ── 5. Trigger: publica no feed ao inserir/atualizar resenha ──────────────────

-- Expande o CHECK de event_type do feed para incluir book_review
ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_event_type_check;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_event_type_check
  CHECK (event_type IN (
    'finished_book', 'started_book', 'streak', 'achievement',
    'goal_completed', 'reading_session', 'joined_club',
    'bet_resolved', 'poll_opened', 'poll_closed',
    'challenge_started', 'challenge_finished', 'seal_awarded',
    'book_review'
  ));

CREATE OR REPLACE FUNCTION notify_club_review_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_book_title TEXT;
BEGIN
  SELECT cbh.book_title INTO v_book_title
  FROM club_book_history cbh WHERE cbh.id = NEW.book_history_id;

  -- Usa rating como campo de rating no feed para renderizar estrelas direto no card.
  -- Ao UPDATE apenas republica se o rating mudou (evita spam).
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.rating IS DISTINCT FROM NEW.rating) THEN
    INSERT INTO social_feed (user_id, event_type, club_id, book_title, rating)
    VALUES (NEW.user_id, 'book_review', NEW.club_id, v_book_title, NEW.rating::int)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_club_review_feed ON club_reviews;
CREATE TRIGGER trg_club_review_feed
  AFTER INSERT OR UPDATE OF rating ON club_reviews
  FOR EACH ROW EXECUTE FUNCTION notify_club_review_event();
