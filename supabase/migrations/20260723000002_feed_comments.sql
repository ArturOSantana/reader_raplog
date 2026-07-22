-- ============================================================
-- READLOG — Comentários do Feed
-- Tabela feed_comments com respostas aninhadas (parent_id)
-- e nível de spoiler.
-- ============================================================

CREATE TABLE IF NOT EXISTS feed_comments (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  feed_id       UUID        NOT NULL REFERENCES social_feed(id) ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id     UUID        REFERENCES feed_comments(id) ON DELETE CASCADE,
  content       TEXT        NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  spoiler_level TEXT        NOT NULL DEFAULT 'none'
                              CHECK (spoiler_level IN ('none', 'partial', 'full')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_comments_feed
  ON feed_comments(feed_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_feed_comments_parent
  ON feed_comments(parent_id)
  WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_feed_comments_user
  ON feed_comments(user_id);

-- Trigger updated_at
CREATE OR REPLACE TRIGGER trg_feed_comments_updated_at
  BEFORE UPDATE ON feed_comments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Contador de comentários no post pai
ALTER TABLE social_feed
  ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION refresh_feed_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_feed_id UUID;
BEGIN
  v_feed_id := COALESCE(NEW.feed_id, OLD.feed_id);
  UPDATE social_feed
  SET comments_count = (
    SELECT COUNT(*) FROM feed_comments WHERE feed_id = v_feed_id
  )
  WHERE id = v_feed_id;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_feed_comments_count
  AFTER INSERT OR DELETE ON feed_comments
  FOR EACH ROW EXECUTE FUNCTION refresh_feed_comments_count();

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE feed_comments ENABLE ROW LEVEL SECURITY;

-- Quem pode ver: mesmo critério do post pai (amigos + membros do clube)
CREATE POLICY "feed_comments: viewer select"
  ON feed_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM social_feed sf
      WHERE sf.id = feed_comments.feed_id
        AND (
          auth.uid() = sf.user_id
          OR (sf.club_id IS NULL AND EXISTS (
            SELECT 1 FROM friends f
            WHERE f.user_id = auth.uid() AND f.friend_id = sf.user_id
          ))
          OR (sf.club_id IS NOT NULL AND is_club_member(sf.club_id, auth.uid()))
        )
    )
  );

-- Qualquer autenticado que vê o post pode comentar
CREATE POLICY "feed_comments: self insert"
  ON feed_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Autor pode editar o próprio comentário
CREATE POLICY "feed_comments: self update"
  ON feed_comments FOR UPDATE
  USING (auth.uid() = user_id);

-- Autor pode deletar o próprio comentário
CREATE POLICY "feed_comments: self delete"
  ON feed_comments FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE feed_comments TO authenticated;
