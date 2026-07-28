-- ============================================================
-- READLOG — Corrige funções faltantes da migration 10
--           e cria club_book_history + club_book_polls
-- A migration 20260722000010 foi registrada mas não completou;
-- este arquivo recria de forma idempotente o que faltou.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Funções auxiliares (migration 10 não as criou)
-- ────────────────────────────────────────────────────────────

-- is_club_owner: somente dono
CREATE OR REPLACE FUNCTION is_club_owner(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role = 'owner'
  );
$$;

-- is_club_manager: dono ou admin
CREATE OR REPLACE FUNCTION is_club_manager(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role IN ('owner', 'admin')
  );
$$;

-- Atualiza is_club_moderator e is_club_admin para delegar a is_club_manager
CREATE OR REPLACE FUNCTION is_club_moderator(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_club_manager(p_club_id, p_user_id);
$$;

CREATE OR REPLACE FUNCTION is_club_admin(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_club_manager(p_club_id, p_user_id);
$$;

-- ────────────────────────────────────────────────────────────
-- 2. Tabela club_book_history
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_book_history (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  book_id       UUID REFERENCES books(id) ON DELETE SET NULL,
  book_title    TEXT NOT NULL,
  book_author   TEXT,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at      TIMESTAMPTZ,
  meeting_count INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_book_history_club
  ON club_book_history(club_id);

CREATE INDEX IF NOT EXISTS idx_club_book_history_started
  ON club_book_history(started_at DESC);

ALTER TABLE club_book_history ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'club_book_history'
      AND policyname = 'club_book_history: member select'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "club_book_history: member select"
        ON club_book_history FOR SELECT
        USING (is_club_member(club_id, auth.uid()))
    $p$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'club_book_history'
      AND policyname = 'club_book_history: manager insert'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "club_book_history: manager insert"
        ON club_book_history FOR INSERT
        WITH CHECK (is_club_manager(club_id, auth.uid()))
    $p$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'club_book_history'
      AND policyname = 'club_book_history: manager update'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "club_book_history: manager update"
        ON club_book_history FOR UPDATE
        USING (is_club_manager(club_id, auth.uid()))
    $p$;
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_book_history TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 3. Tabelas de votação de livros (club_book_polls)
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_book_polls (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     UUID NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  status      TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open', 'closed')),
  closes_at   TIMESTAMPTZ,
  created_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_book_polls_club
  ON club_book_polls(club_id);

CREATE INDEX IF NOT EXISTS idx_club_book_polls_status
  ON club_book_polls(status);

ALTER TABLE club_book_polls ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_polls' AND policyname='club_book_polls: member select') THEN
    EXECUTE $p$ CREATE POLICY "club_book_polls: member select" ON club_book_polls FOR SELECT USING (is_club_member(club_id, auth.uid())) $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_polls' AND policyname='club_book_polls: manager insert') THEN
    EXECUTE $p$ CREATE POLICY "club_book_polls: manager insert" ON club_book_polls FOR INSERT WITH CHECK (is_club_manager(club_id, auth.uid())) $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_polls' AND policyname='club_book_polls: manager update') THEN
    EXECUTE $p$ CREATE POLICY "club_book_polls: manager update" ON club_book_polls FOR UPDATE USING (is_club_manager(club_id, auth.uid())) $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_polls' AND policyname='club_book_polls: manager delete') THEN
    EXECUTE $p$ CREATE POLICY "club_book_polls: manager delete" ON club_book_polls FOR DELETE USING (is_club_manager(club_id, auth.uid())) $p$;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS club_book_poll_options (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     UUID NOT NULL REFERENCES club_book_polls(id) ON DELETE CASCADE,
  book_title  TEXT NOT NULL,
  book_author TEXT,
  book_id     UUID REFERENCES books(id) ON DELETE SET NULL,
  vote_count  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_book_poll_options_poll
  ON club_book_poll_options(poll_id);

ALTER TABLE club_book_poll_options ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_options' AND policyname='club_book_poll_options: member select') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_options: member select"
        ON club_book_poll_options FOR SELECT
        USING (EXISTS (SELECT 1 FROM club_book_polls p WHERE p.id = poll_id AND is_club_member(p.club_id, auth.uid())))
    $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_options' AND policyname='club_book_poll_options: manager insert') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_options: manager insert"
        ON club_book_poll_options FOR INSERT
        WITH CHECK (EXISTS (SELECT 1 FROM club_book_polls p WHERE p.id = poll_id AND is_club_manager(p.club_id, auth.uid())))
    $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_options' AND policyname='club_book_poll_options: manager delete') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_options: manager delete"
        ON club_book_poll_options FOR DELETE
        USING (EXISTS (SELECT 1 FROM club_book_polls p WHERE p.id = poll_id AND is_club_manager(p.club_id, auth.uid())))
    $p$;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS club_book_poll_votes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id    UUID NOT NULL REFERENCES club_book_polls(id) ON DELETE CASCADE,
  option_id  UUID NOT NULL REFERENCES club_book_poll_options(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (poll_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_club_book_poll_votes_poll
  ON club_book_poll_votes(poll_id);

ALTER TABLE club_book_poll_votes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_votes' AND policyname='club_book_poll_votes: member select') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_votes: member select"
        ON club_book_poll_votes FOR SELECT
        USING (EXISTS (SELECT 1 FROM club_book_polls p WHERE p.id = poll_id AND is_club_member(p.club_id, auth.uid())))
    $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_votes' AND policyname='club_book_poll_votes: member insert') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_votes: member insert"
        ON club_book_poll_votes FOR INSERT
        WITH CHECK (
          auth.uid() = user_id
          AND EXISTS (
            SELECT 1 FROM club_book_polls p
            WHERE p.id = poll_id AND p.status = 'open'
              AND is_club_member(p.club_id, auth.uid())
          )
        )
    $p$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='club_book_poll_votes' AND policyname='club_book_poll_votes: self delete') THEN
    EXECUTE $p$
      CREATE POLICY "club_book_poll_votes: self delete"
        ON club_book_poll_votes FOR DELETE
        USING (auth.uid() = user_id)
    $p$;
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_book_polls        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_book_poll_options TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_book_poll_votes   TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 4. Função RPC: vote_on_book_poll
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION vote_on_book_poll(
  p_poll_id   UUID,
  p_option_id UUID
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user    UUID := auth.uid();
  v_old_opt UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM club_book_polls p
    WHERE p.id = p_poll_id
      AND p.status = 'open'
      AND is_club_member(p.club_id, v_user)
  ) THEN
    RAISE EXCEPTION 'Enquete não encontrada, encerrada ou usuário não é membro';
  END IF;

  SELECT option_id INTO v_old_opt
  FROM club_book_poll_votes
  WHERE poll_id = p_poll_id AND user_id = v_user;

  IF v_old_opt IS NOT NULL THEN
    IF v_old_opt = p_option_id THEN
      DELETE FROM club_book_poll_votes
      WHERE poll_id = p_poll_id AND user_id = v_user;
      UPDATE club_book_poll_options
      SET vote_count = GREATEST(vote_count - 1, 0)
      WHERE id = v_old_opt;
      RETURN;
    END IF;
    DELETE FROM club_book_poll_votes
    WHERE poll_id = p_poll_id AND user_id = v_user;
    UPDATE club_book_poll_options
    SET vote_count = GREATEST(vote_count - 1, 0)
    WHERE id = v_old_opt;
  END IF;

  INSERT INTO club_book_poll_votes (poll_id, option_id, user_id)
  VALUES (p_poll_id, p_option_id, v_user);

  UPDATE club_book_poll_options
  SET vote_count = vote_count + 1
  WHERE id = p_option_id;
END;
$$;

GRANT EXECUTE ON FUNCTION vote_on_book_poll(UUID, UUID) TO authenticated;
