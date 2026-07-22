-- ============================================================
-- READLOG — Feed do Clube
-- Adiciona: club_id em social_feed, event_type reading_session
--           e RLS para membros do clube verem o feed do clube.
-- ============================================================

-- ── 1. Novo campo club_id e páginas lidas na sessão ──────────
ALTER TABLE social_feed
  ADD COLUMN IF NOT EXISTS club_id       UUID REFERENCES book_clubs(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS pages_read    INTEGER,
  ADD COLUMN IF NOT EXISTS current_page  INTEGER,
  ADD COLUMN IF NOT EXISTS session_minutes INTEGER;

CREATE INDEX IF NOT EXISTS idx_social_feed_club
  ON social_feed(club_id, created_at DESC)
  WHERE club_id IS NOT NULL;

-- ── 2. Novo event_type reading_session ───────────────────────
-- Recria o CHECK constraint incluindo o novo tipo.
ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_event_type_check;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_event_type_check
  CHECK (event_type IN (
    'finished_book',
    'started_book',
    'streak',
    'achievement',
    'goal_completed',
    'reading_session',
    'joined_club'
  ));

-- ── 3. RLS — membros do clube veem o feed do clube ───────────
-- Remove política antiga (feed global de amigos) e recria
-- abrangendo também o feed filtrado por clube.

DROP POLICY IF EXISTS "social_feed: friends select" ON social_feed;

CREATE POLICY "social_feed: friends or club select"
  ON social_feed FOR SELECT
  USING (
    -- próprio usuário sempre vê
    auth.uid() = user_id
    OR
    -- feed global: amigos
    (
      club_id IS NULL
      AND EXISTS (
        SELECT 1 FROM friends f
        WHERE f.user_id = auth.uid() AND f.friend_id = social_feed.user_id
      )
    )
    OR
    -- feed de clube: qualquer membro vê posts do clube
    (
      club_id IS NOT NULL
      AND is_club_member(club_id, auth.uid())
    )
  );

-- ── 4. Trigger: gera check-in automático ao finalizar sessão ─
-- Quando uma reading_session muda para 'finished' e pertence
-- a um livro que é o current_book de algum clube do usuário,
-- insere automaticamente um evento reading_session no feed
-- desse clube.

CREATE OR REPLACE FUNCTION auto_checkin_after_session()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  -- Só dispara ao finalizar (transição para 'finished')
  IF NEW.status != 'finished' OR OLD.status = 'finished' THEN
    RETURN NEW;
  END IF;

  -- Descobre se o livro é o livro atual de algum clube do usuário
  SELECT bc.id INTO v_club_id
  FROM book_clubs bc
  JOIN book_club_members bcm ON bcm.club_id = bc.id
  WHERE bcm.user_id = NEW.user_id
    AND bc.current_book_id = NEW.book_id
    AND bc.status = 'active'
  LIMIT 1;

  IF v_club_id IS NULL THEN
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
