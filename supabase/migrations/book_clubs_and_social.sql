  -- ============================================================
  -- READLOG — Clube do Livro, Encontros e Feed Social
  -- Execute no SQL Editor do Supabase Dashboard
  -- ============================================================

  -- ────────────────────────────────────────────────────────────
  -- book_clubs
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS book_clubs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    description         TEXT,
    cover_url           TEXT,
    current_book_id     UUID REFERENCES books(id) ON DELETE SET NULL,
    current_book_title  TEXT,
    current_book_author TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_book_clubs_admin ON book_clubs(admin_id);

  ALTER TABLE book_clubs ENABLE ROW LEVEL SECURITY;

  -- Qualquer autenticado pode ler clubes (para busca/convite)
  CREATE POLICY "book_clubs: authenticated read"
    ON book_clubs FOR SELECT
    USING (auth.role() = 'authenticated');

  CREATE POLICY "book_clubs: admin insert"
    ON book_clubs FOR INSERT
    WITH CHECK (auth.uid() = admin_id);

  CREATE POLICY "book_clubs: admin update"
    ON book_clubs FOR UPDATE
    USING (auth.uid() = admin_id);

  CREATE POLICY "book_clubs: admin delete"
    ON book_clubs FOR DELETE
    USING (auth.uid() = admin_id);

  -- ────────────────────────────────────────────────────────────
  -- book_club_members
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS book_club_members (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id   UUID NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role      TEXT NOT NULL DEFAULT 'member'
                CHECK (role IN ('admin', 'moderator', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (club_id, user_id)
  );

  CREATE INDEX IF NOT EXISTS idx_club_members_club   ON book_club_members(club_id);
  CREATE INDEX IF NOT EXISTS idx_club_members_user   ON book_club_members(user_id);

  ALTER TABLE book_club_members ENABLE ROW LEVEL SECURITY;

  -- Membros veem outros membros do mesmo clube
  CREATE POLICY "club_members: member select"
    ON book_club_members FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM book_club_members m2
        WHERE m2.club_id = book_club_members.club_id
          AND m2.user_id = auth.uid()
      )
    );

  -- Usuário pode entrar (inserir a si mesmo como member)
  CREATE POLICY "club_members: self insert"
    ON book_club_members FOR INSERT
    WITH CHECK (auth.uid() = user_id);

  -- Apenas admin/moderador pode alterar papéis
  CREATE POLICY "club_members: moderator update"
    ON book_club_members FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM book_club_members m2
        WHERE m2.club_id = book_club_members.club_id
          AND m2.user_id = auth.uid()
          AND m2.role IN ('admin', 'moderator')
      )
    );

  -- Membro pode sair (deletar a si mesmo); admin pode remover qualquer um
  CREATE POLICY "club_members: self or admin delete"
    ON book_club_members FOR DELETE
    USING (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM book_club_members m2
        WHERE m2.club_id = book_club_members.club_id
          AND m2.user_id = auth.uid()
          AND m2.role = 'admin'
      )
    );

  -- ────────────────────────────────────────────────────────────
  -- book_club_meetings  (encontros)
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS book_club_meetings (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id      UUID NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    location     TEXT,
    online_link  TEXT,
    notes        TEXT,
    going_count  INT NOT NULL DEFAULT 0,
    maybe_count  INT NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_meetings_club      ON book_club_meetings(club_id);
  CREATE INDEX IF NOT EXISTS idx_meetings_scheduled ON book_club_meetings(scheduled_at);

  ALTER TABLE book_club_meetings ENABLE ROW LEVEL SECURITY;

  -- Membros do clube veem encontros
  CREATE POLICY "meetings: member select"
    ON book_club_meetings FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM book_club_members m
        WHERE m.club_id = book_club_meetings.club_id
          AND m.user_id = auth.uid()
      )
    );

  -- Admin/moderador cria encontros
  CREATE POLICY "meetings: moderator insert"
    ON book_club_meetings FOR INSERT
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM book_club_members m
        WHERE m.club_id = club_id
          AND m.user_id = auth.uid()
          AND m.role IN ('admin', 'moderator')
      )
    );

  CREATE POLICY "meetings: moderator update"
    ON book_club_meetings FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM book_club_members m
        WHERE m.club_id = book_club_meetings.club_id
          AND m.user_id = auth.uid()
          AND m.role IN ('admin', 'moderator')
      )
    );

  CREATE POLICY "meetings: moderator delete"
    ON book_club_meetings FOR DELETE
    USING (
      EXISTS (
        SELECT 1 FROM book_club_members m
        WHERE m.club_id = book_club_meetings.club_id
          AND m.user_id = auth.uid()
          AND m.role IN ('admin', 'moderator')
      )
    );

  -- ────────────────────────────────────────────────────────────
  -- meeting_rsvps  (confirmação de presença)
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS meeting_rsvps (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES book_club_meetings(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rsvp       TEXT NOT NULL DEFAULT 'no_response'
                CHECK (rsvp IN ('going', 'maybe', 'not_going', 'no_response')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (meeting_id, user_id)
  );

  CREATE INDEX IF NOT EXISTS idx_rsvps_meeting ON meeting_rsvps(meeting_id);
  CREATE INDEX IF NOT EXISTS idx_rsvps_user    ON meeting_rsvps(user_id);

  ALTER TABLE meeting_rsvps ENABLE ROW LEVEL SECURITY;

  -- Membros do clube veem RSVPs
  CREATE POLICY "rsvps: member select"
    ON meeting_rsvps FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM book_club_meetings mt
        JOIN book_club_members m ON m.club_id = mt.club_id
        WHERE mt.id = meeting_rsvps.meeting_id
          AND m.user_id = auth.uid()
      )
    );

  CREATE POLICY "rsvps: self insert"
    ON meeting_rsvps FOR INSERT
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "rsvps: self update"
    ON meeting_rsvps FOR UPDATE
    USING (auth.uid() = user_id);

  -- ────────────────────────────────────────────────────────────
  -- FUNCTION: atualizar contadores de RSVP no encontro
  -- ────────────────────────────────────────────────────────────
  CREATE OR REPLACE FUNCTION refresh_meeting_rsvp_counts()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
  DECLARE
    v_meeting_id UUID;
  BEGIN
    v_meeting_id := COALESCE(NEW.meeting_id, OLD.meeting_id);
    UPDATE book_club_meetings
    SET
      going_count = (
        SELECT COUNT(*) FROM meeting_rsvps
        WHERE meeting_id = v_meeting_id AND rsvp = 'going'
      ),
      maybe_count = (
        SELECT COUNT(*) FROM meeting_rsvps
        WHERE meeting_id = v_meeting_id AND rsvp = 'maybe'
      )
    WHERE id = v_meeting_id;
    RETURN NULL;
  END;
  $$;

  CREATE OR REPLACE TRIGGER trg_rsvp_counts
    AFTER INSERT OR UPDATE OR DELETE ON meeting_rsvps
    FOR EACH ROW EXECUTE FUNCTION refresh_meeting_rsvp_counts();

  -- ────────────────────────────────────────────────────────────
  -- social_feed  (eventos públicos: livros, ofensivas, conquistas)
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS social_feed (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type         TEXT NOT NULL
                        CHECK (event_type IN (
                          'finished_book', 'started_book',
                          'streak', 'achievement', 'goal_completed'
                        )),
    book_title         TEXT,
    book_author        TEXT,
    rating             INT,
    streak_days        INT,
    achievement_name   TEXT,
    goal_description   TEXT,
    likes_count        INT NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_feed_user    ON social_feed(user_id);
  CREATE INDEX IF NOT EXISTS idx_feed_created ON social_feed(created_at DESC);

  ALTER TABLE social_feed ENABLE ROW LEVEL SECURITY;

  -- Amigos do usuário veem o feed (+ o próprio usuário)
  CREATE POLICY "social_feed: friends select"
    ON social_feed FOR SELECT
    USING (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM friends f
        WHERE f.user_id = auth.uid() AND f.friend_id = social_feed.user_id
      )
    );

  CREATE POLICY "social_feed: owner insert"
    ON social_feed FOR INSERT
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "social_feed: owner delete"
    ON social_feed FOR DELETE
    USING (auth.uid() = user_id);

  -- ────────────────────────────────────────────────────────────
  -- feed_likes
  -- ────────────────────────────────────────────────────────────
  CREATE TABLE IF NOT EXISTS feed_likes (
    feed_id UUID NOT NULL REFERENCES social_feed(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    PRIMARY KEY (feed_id, user_id)
  );

  ALTER TABLE feed_likes ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "feed_likes: friend select"
    ON feed_likes FOR SELECT
    USING (auth.role() = 'authenticated');

  CREATE POLICY "feed_likes: self insert"
    ON feed_likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "feed_likes: self delete"
    ON feed_likes FOR DELETE
    USING (auth.uid() = user_id);

  -- Trigger: atualiza likes_count
  CREATE OR REPLACE FUNCTION refresh_feed_likes_count()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
  BEGIN
    UPDATE social_feed
    SET likes_count = (
      SELECT COUNT(*) FROM feed_likes
      WHERE feed_id = COALESCE(NEW.feed_id, OLD.feed_id)
    )
    WHERE id = COALESCE(NEW.feed_id, OLD.feed_id);
    RETURN NULL;
  END;
  $$;

  CREATE OR REPLACE TRIGGER trg_feed_likes_count
    AFTER INSERT OR DELETE ON feed_likes
    FOR EACH STATEMENT EXECUTE FUNCTION refresh_feed_likes_count();

  -- ────────────────────────────────────────────────────────────
  -- VIEW: member_count por clube
  -- ────────────────────────────────────────────────────────────
  CREATE OR REPLACE VIEW book_clubs_with_count AS
    SELECT bc.*,
          COUNT(m.id) AS member_count
    FROM book_clubs bc
    LEFT JOIN book_club_members m ON m.club_id = bc.id
    GROUP BY bc.id;
