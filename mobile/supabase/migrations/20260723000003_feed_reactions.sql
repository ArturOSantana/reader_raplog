-- ============================================================
-- READLOG — Reações tipadas no Feed
-- Substitui o like binário (feed_likes) por reações com emoji.
-- feed_likes continua existindo para compatibilidade; as reações
-- são independentes e adicionam expressividade sem quebrar nada.
-- ============================================================

CREATE TABLE IF NOT EXISTS feed_reactions (
  feed_id       UUID NOT NULL REFERENCES social_feed(id)  ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  reaction_type TEXT NOT NULL
                  CHECK (reaction_type IN (
                    'heart',
                    'book',
                    'fire',
                    'clap',
                    'brain',
                    'coffee',
                    'love_eyes'
                  )),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (feed_id, user_id, reaction_type)
);

CREATE INDEX IF NOT EXISTS idx_feed_reactions_feed
  ON feed_reactions(feed_id);

CREATE INDEX IF NOT EXISTS idx_feed_reactions_user
  ON feed_reactions(user_id);

-- Coluna de contagem agregada no post (JSON: {"heart":3,"fire":1,...})
ALTER TABLE social_feed
  ADD COLUMN IF NOT EXISTS reactions_summary JSONB NOT NULL DEFAULT '{}';

CREATE OR REPLACE FUNCTION refresh_feed_reactions_summary()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_feed_id UUID;
BEGIN
  v_feed_id := COALESCE(NEW.feed_id, OLD.feed_id);
  UPDATE social_feed
  SET reactions_summary = (
    SELECT COALESCE(
      jsonb_object_agg(reaction_type, cnt),
      '{}'::jsonb
    )
    FROM (
      SELECT reaction_type, COUNT(*) AS cnt
      FROM feed_reactions
      WHERE feed_id = v_feed_id
      GROUP BY reaction_type
    ) t
  )
  WHERE id = v_feed_id;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_feed_reactions_summary
  AFTER INSERT OR DELETE ON feed_reactions
  FOR EACH ROW EXECUTE FUNCTION refresh_feed_reactions_summary();

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE feed_reactions ENABLE ROW LEVEL SECURITY;

-- Mesma visibilidade do post pai
CREATE POLICY "feed_reactions: viewer select"
  ON feed_reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM social_feed sf
      WHERE sf.id = feed_reactions.feed_id
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

-- Usuário reage (máx. 1 reação de cada tipo por post)
CREATE POLICY "feed_reactions: self insert"
  ON feed_reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usuário remove a própria reação
CREATE POLICY "feed_reactions: self delete"
  ON feed_reactions FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON TABLE feed_reactions TO authenticated;
