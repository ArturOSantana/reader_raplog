-- ============================================================
-- READLOG V2 — Stories 24h do Clube
-- ============================================================
-- Um story é um post efêmero associado a um clube, com duração
-- padrão de 24 horas. Pode ser texto, imagem ou referência a
-- um livro em leitura.
-- ============================================================

-- ── 1. Tabela club_stories ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_stories (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID        NOT NULL REFERENCES book_clubs(id)   ON DELETE CASCADE,
  author_id     UUID        NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  -- Tipo de conteúdo
  story_type    TEXT        NOT NULL DEFAULT 'text'
                              CHECK (story_type IN ('text', 'image', 'book_progress')),
  -- Conteúdo
  content       TEXT,                       -- texto livre (max 300 chars)
  image_url     TEXT,                       -- URL da imagem (storage)
  book_id       UUID        REFERENCES books(id) ON DELETE SET NULL,
  caption       TEXT,                       -- legenda opcional para imagem/progresso
  -- Controle de expiração
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Validação: text requer content, image requer image_url
  CONSTRAINT story_content_check CHECK (
    (story_type = 'text'          AND content IS NOT NULL) OR
    (story_type = 'image'         AND image_url IS NOT NULL) OR
    (story_type = 'book_progress' AND book_id IS NOT NULL) OR
    story_type NOT IN ('text', 'image', 'book_progress')
  ),
  CONSTRAINT story_content_length CHECK (
    content IS NULL OR char_length(content) <= 300
  )
);

CREATE INDEX IF NOT EXISTS idx_club_stories_club_active
  ON club_stories(club_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_club_stories_author
  ON club_stories(author_id);

ALTER TABLE club_stories ENABLE ROW LEVEL SECURITY;

-- Membros veem stories ativos do clube
CREATE POLICY "stories: member select active"
  ON club_stories FOR SELECT
  USING (
    is_club_member(club_id, auth.uid())
    AND expires_at > NOW()
  );

-- Qualquer membro pode publicar story
CREATE POLICY "stories: member insert"
  ON club_stories FOR INSERT
  WITH CHECK (
    auth.uid() = author_id
    AND is_club_member(club_id, auth.uid())
  );

-- Autor pode deletar o próprio story; manager pode deletar qualquer um
CREATE POLICY "stories: author or manager delete"
  ON club_stories FOR DELETE
  USING (
    auth.uid() = author_id
    OR is_club_manager(club_id, auth.uid())
  );

GRANT SELECT, INSERT, DELETE ON TABLE club_stories TO authenticated;

-- ── 2. Views vistas de stories ─────────────────────────────────────────────────
-- Retorna stories ativos com nome e avatar do autor

CREATE OR REPLACE VIEW active_club_stories AS
SELECT
  cs.id,
  cs.club_id,
  cs.story_type,
  cs.content,
  cs.image_url,
  cs.book_id,
  cs.caption,
  cs.expires_at,
  cs.created_at,
  -- Autor
  cs.author_id,
  p.name       AS author_name,
  p.avatar_url AS author_avatar,
  -- Livro (quando book_progress)
  b.title      AS book_title,
  b.cover_url  AS book_cover_url
FROM club_stories cs
LEFT JOIN profiles p ON p.id = cs.author_id
LEFT JOIN books    b ON b.id = cs.book_id
WHERE cs.expires_at > NOW();

GRANT SELECT ON active_club_stories TO authenticated;

-- ── 3. Visualizações de story (quem assistiu) ────────────────────────────────

CREATE TABLE IF NOT EXISTS club_story_views (
  story_id    UUID        NOT NULL REFERENCES club_stories(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, user_id)
);

ALTER TABLE club_story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "story_views: member insert"
  ON club_story_views FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "story_views: author select"
  ON club_story_views FOR SELECT
  USING (
    -- O autor do story pode ver quem assistiu
    EXISTS (
      SELECT 1 FROM club_stories cs
      WHERE cs.id = story_id AND cs.author_id = auth.uid()
    )
    OR auth.uid() = user_id
  );

GRANT SELECT, INSERT ON TABLE club_story_views TO authenticated;

-- ── 4. Função: publicar story ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_club_story(
  p_club_id     UUID,
  p_story_type  TEXT,
  p_content     TEXT     DEFAULT NULL,
  p_image_url   TEXT     DEFAULT NULL,
  p_book_id     UUID     DEFAULT NULL,
  p_caption     TEXT     DEFAULT NULL,
  p_duration_hours INTEGER DEFAULT 24
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_story_id UUID;
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado: não é membro do clube';
  END IF;

  INSERT INTO club_stories (
    club_id, author_id, story_type,
    content, image_url, book_id, caption,
    expires_at
  ) VALUES (
    p_club_id, auth.uid(), p_story_type,
    p_content, p_image_url, p_book_id, p_caption,
    NOW() + (p_duration_hours || ' hours')::INTERVAL
  )
  RETURNING id INTO v_story_id;

  RETURN v_story_id;
END;
$$;

GRANT EXECUTE ON FUNCTION create_club_story(UUID, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER)
  TO authenticated;

-- ── 5. Função: marcar story como visto ───────────────────────────────────────

CREATE OR REPLACE FUNCTION mark_story_viewed(p_story_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO club_story_views (story_id, user_id)
  VALUES (p_story_id, auth.uid())
  ON CONFLICT (story_id, user_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_story_viewed(UUID) TO authenticated;
