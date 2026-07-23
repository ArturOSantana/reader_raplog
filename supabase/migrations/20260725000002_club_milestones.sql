-- ============================================================
-- READLOG — Marcos de Progresso + Fóruns Anti-Spoiler
-- M-02: marcos em 25/50/75/100% do livro atual.
-- Cada marco possui um fórum próprio; tópicos só aparecem
-- para quem já atingiu aquele percentual de leitura.
-- ============================================================

-- ── 1. Tabela de marcos ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS club_milestones (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id           UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  book_history_id   UUID        REFERENCES club_book_history(id)   ON DELETE SET NULL,
  milestone_pct     INTEGER     NOT NULL CHECK (milestone_pct IN (25, 50, 75, 100)),
  title             TEXT,                         -- ex: "25% — O começo"
  unlocked_at       TIMESTAMPTZ,                  -- NULL enquanto ninguém chegou
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (club_id, book_history_id, milestone_pct)
);

CREATE INDEX IF NOT EXISTS idx_club_milestones_club
  ON club_milestones(club_id, milestone_pct ASC);

ALTER TABLE club_milestones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "milestones: member select"
  ON club_milestones FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

CREATE POLICY "milestones: manager insert"
  ON club_milestones FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

CREATE POLICY "milestones: manager update"
  ON club_milestones FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE ON TABLE club_milestones TO authenticated;

-- ── 2. Tópicos de discussão do marco ─────────────────────────
-- Cada tópico pertence a um marco e tem seu próprio thread.
CREATE TABLE IF NOT EXISTS club_milestone_topics (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id  UUID        NOT NULL REFERENCES club_milestones(id) ON DELETE CASCADE,
  club_id       UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content       TEXT        NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  parent_id     UUID        REFERENCES club_milestone_topics(id) ON DELETE CASCADE,
  spoiler_level TEXT        NOT NULL DEFAULT 'none'
                              CHECK (spoiler_level IN ('none', 'partial', 'full')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_milestone_topics_milestone
  ON club_milestone_topics(milestone_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_milestone_topics_club
  ON club_milestone_topics(club_id);

ALTER TABLE club_milestone_topics ENABLE ROW LEVEL SECURITY;

-- Política anti-spoiler: membro só vê tópicos de marcos que ele já atingiu.
-- "Atingiu" = seu avg_current_page / total_pages >= milestone_pct/100
-- Simplificação segura: apenas membros que já têm sessões concluindo >= X% da
-- leitura ou managers (que podem ver tudo para moderação).
CREATE POLICY "milestone_topics: anti_spoiler select"
  ON club_milestone_topics FOR SELECT
  USING (
    -- managers sempre veem (para moderação)
    is_club_manager(club_id, auth.uid())
    OR
    -- membro vê se já ultrapassou o percentual do marco
    EXISTS (
      SELECT 1
      FROM club_milestones cm
      JOIN book_clubs bc ON bc.id = cm.club_id
      JOIN books bk ON bk.id = bc.current_book_id
      JOIN reading_sessions rs
        ON rs.user_id = auth.uid()
       AND rs.book_id = bk.id
       AND rs.status  = 'finished'
      WHERE cm.id = club_milestone_topics.milestone_id
        AND bk.total_pages > 0
        AND rs.end_page::NUMERIC / bk.total_pages * 100 >= cm.milestone_pct
    )
  );

CREATE POLICY "milestone_topics: member insert"
  ON club_milestone_topics FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND is_club_member(club_id, auth.uid())
  );

CREATE POLICY "milestone_topics: self update"
  ON club_milestone_topics FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "milestone_topics: self or manager delete"
  ON club_milestone_topics FOR DELETE
  USING (auth.uid() = user_id OR is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_milestone_topics TO authenticated;

-- Trigger updated_at
CREATE OR REPLACE TRIGGER trg_milestone_topics_updated_at
  BEFORE UPDATE ON club_milestone_topics
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── 3. RPC: cria os 4 marcos para o ciclo atual ───────────────
-- Chamado ao definir um novo livro (set_current_book) ou manualmente.
CREATE OR REPLACE FUNCTION create_milestones_for_cycle(p_club_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_history_id UUID;
BEGIN
  IF NOT is_club_manager(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Pega o ciclo aberto atual
  SELECT id INTO v_history_id
  FROM club_book_history
  WHERE club_id = p_club_id AND ended_at IS NULL
  ORDER BY started_at DESC
  LIMIT 1;

  -- Insere os 4 marcos (ignora se já existirem)
  INSERT INTO club_milestones (club_id, book_history_id, milestone_pct, title)
  VALUES
    (p_club_id, v_history_id, 25,  '25% — Primeiras impressões'),
    (p_club_id, v_history_id, 50,  '50% — No meio do caminho'),
    (p_club_id, v_history_id, 75,  '75% — Reta final'),
    (p_club_id, v_history_id, 100, '100% — Livro concluído')
  ON CONFLICT (club_id, book_history_id, milestone_pct) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION create_milestones_for_cycle(UUID) TO authenticated;
