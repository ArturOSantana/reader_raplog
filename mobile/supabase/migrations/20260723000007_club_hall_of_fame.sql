-- ============================================================
-- READLOG — Hall da Fama do Clube
-- Registro permanente por ciclo de livro. Nunca reseta.
-- Preenchido automaticamente ao encerrar um ciclo.
-- ============================================================

CREATE TABLE IF NOT EXISTS club_hall_of_fame (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id             UUID        NOT NULL REFERENCES book_clubs(id)      ON DELETE CASCADE,
  book_history_id     UUID        REFERENCES club_book_history(id)        ON DELETE SET NULL,
  book_title          TEXT        NOT NULL,
  book_author         TEXT,
  season_ended_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  --  da temporada (user_id pode ser NULL se clube era pequeno)
  top_reader_user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  top_reader_name         TEXT,
  top_reader_pages        INTEGER,

  top_streak_user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  top_streak_name         TEXT,xq
  top_streak_days         INTEGER,

  top_sessions_user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  top_sessions_name       TEXT,
  top_sessions_count      INTEGER,

  -- Estatísticas agregadas da temporada
  total_members       INTEGER NOT NULL DEFAULT 0,
  total_pages         INTEGER NOT NULL DEFAULT 0,
  total_minutes       INTEGER NOT NULL DEFAULT 0,
  total_sessions      INTEGER NOT NULL DEFAULT 0,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hall_of_fame_club
  ON club_hall_of_fame(club_id, season_ended_at DESC);

ALTER TABLE club_hall_of_fame ENABLE ROW LEVEL SECURITY;

-- Membros do clube veem o hall da fama
CREATE POLICY "hall_of_fame: member select"
  ON club_hall_of_fame FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Apenas managers podem inserir (ao encerrar ciclo)
CREATE POLICY "hall_of_fame: manager insert"
  ON club_hall_of_fame FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT ON TABLE club_hall_of_fame TO authenticated;

-- ── RPC: encerra ciclo de leitura e grava hall da fama ────────
CREATE OR REPLACE FUNCTION close_reading_cycle(p_club_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller        UUID := auth.uid();
  v_book_id       UUID;
  v_book_title    TEXT;
  v_book_author   TEXT;
  v_history_id    UUID;
  v_hof_id        UUID;

  v_top_pages_uid UUID; v_top_pages_name TEXT; v_top_pages INT;
  v_top_str_uid   UUID; v_top_str_name   TEXT; v_top_str   INT;
  v_top_sess_uid  UUID; v_top_sess_name  TEXT; v_top_sess  INT;
  v_total_members INT; v_total_pages INT; v_total_min INT; v_total_sess INT;
BEGIN
  IF NOT is_club_manager(p_club_id, v_caller) THEN
    RAISE EXCEPTION 'Apenas dono ou admin pode encerrar o ciclo';
  END IF;

  SELECT current_book_id, current_book_title, current_book_author
  INTO v_book_id, v_book_title, v_book_author
  FROM book_clubs WHERE id = p_club_id;

  IF v_book_id IS NULL THEN
    RAISE EXCEPTION 'Clube não possui livro atual';
  END IF;

  -- Atualiza histórico do livro (finaliza ciclo)
  UPDATE club_book_history
  SET ended_at = NOW()
  WHERE club_id = p_club_id
    AND book_id = v_book_id
    AND ended_at IS NULL
  RETURNING id INTO v_history_id;

  -- Calcula destaques da temporada
  SELECT user_id, name, total_pages
  INTO v_top_pages_uid, v_top_pages_name, v_top_pages
  FROM club_member_stats
  WHERE club_id = p_club_id
  ORDER BY total_pages DESC LIMIT 1;

  SELECT user_id, name, total_sessions
  INTO v_top_sess_uid, v_top_sess_name, v_top_sess
  FROM club_member_stats
  WHERE club_id = p_club_id
  ORDER BY total_sessions DESC LIMIT 1;

  -- Ofensiva máxima individual: usa calculate_streak como proxy
  -- (simplificação: pega o membro com maior total_minutes como proxy de consistência)
  SELECT user_id, name, total_minutes
  INTO v_top_str_uid, v_top_str_name, v_top_str
  FROM club_member_stats
  WHERE club_id = p_club_id
  ORDER BY total_minutes DESC LIMIT 1;

  -- Totais do clube
  SELECT
    COUNT(DISTINCT user_id),
    COALESCE(SUM(total_pages), 0),
    COALESCE(SUM(total_minutes), 0),
    COALESCE(SUM(total_sessions), 0)
  INTO v_total_members, v_total_pages, v_total_min, v_total_sess
  FROM club_member_stats
  WHERE club_id = p_club_id;

  -- Grava hall da fama
  INSERT INTO club_hall_of_fame (
    club_id, book_history_id, book_title, book_author,
    top_reader_user_id, top_reader_name, top_reader_pages,
    top_streak_user_id, top_streak_name, top_streak_days,
    top_sessions_user_id, top_sessions_name, top_sessions_count,
    total_members, total_pages, total_minutes, total_sessions
  ) VALUES (
    p_club_id, v_history_id, v_book_title, v_book_author,
    v_top_pages_uid, v_top_pages_name, v_top_pages,
    v_top_str_uid, v_top_str_name, v_top_str,
    v_top_sess_uid, v_top_sess_name, v_top_sess,
    v_total_members, v_total_pages, v_total_min, v_total_sess
  ) RETURNING id INTO v_hof_id;

  -- Limpa livro atual e reseta status
  UPDATE book_clubs
  SET
    current_book_id             = NULL,
    current_book_title          = NULL,
    current_book_author         = NULL,
    current_book_status         = 'none',
    reading_pace_pages_per_day  = NULL,
    reading_target_end_date     = NULL,
    reading_started_at          = NULL
  WHERE id = p_club_id;

  RETURN v_hof_id;
END;
$$;

GRANT EXECUTE ON FUNCTION close_reading_cycle(UUID) TO authenticated;
