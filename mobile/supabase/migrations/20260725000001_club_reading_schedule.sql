-- ============================================================
-- READLOG — Ritmo do Clube (Reading Schedule)
-- M-01: cronograma semanal por capítulos/intervalos de página.
-- Permite ao admin definir o ritmo e habilita anti-spoiler.
-- ============================================================

CREATE TABLE IF NOT EXISTS club_reading_schedule (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id      UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  -- Número da semana a partir do início da leitura (1-based)
  week_number  INTEGER     NOT NULL CHECK (week_number >= 1),
  title        TEXT,                              -- ex: "Semana 1 — Capítulos 1–3"
  chapter_from TEXT,                              -- capítulo ou seção inicial (texto livre)
  chapter_to   TEXT,                              -- capítulo ou seção final
  page_from    INTEGER,                           -- página inicial (opcional)
  page_to      INTEGER,                           -- página final (opcional)
  target_date  DATE,                              -- data-alvo para concluir esse bloco
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (club_id, week_number)
);

CREATE INDEX IF NOT EXISTS idx_club_reading_schedule_club
  ON club_reading_schedule(club_id, week_number ASC);

ALTER TABLE club_reading_schedule ENABLE ROW LEVEL SECURITY;

-- Membros veem o cronograma
CREATE POLICY "reading_schedule: member select"
  ON club_reading_schedule FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Apenas managers criam/alteram/removem entradas do cronograma
CREATE POLICY "reading_schedule: manager insert"
  ON club_reading_schedule FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

CREATE POLICY "reading_schedule: manager update"
  ON club_reading_schedule FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

CREATE POLICY "reading_schedule: manager delete"
  ON club_reading_schedule FOR DELETE
  USING (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_reading_schedule TO authenticated;
