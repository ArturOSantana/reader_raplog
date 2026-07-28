-- ============================================================
-- READLOG — Mini Resenha por Sessão (M-05) +
--           Origem do Livro na Biblioteca (M-04)
-- ============================================================

-- ── M-05: mood + mini_review em reading_sessions ─────────────
ALTER TABLE reading_sessions
  ADD COLUMN IF NOT EXISTS mood        TEXT
    CHECK (mood IN ('happy', 'neutral', 'confused', 'bored', 'excited')),
  ADD COLUMN IF NOT EXISTS mini_review TEXT
    CHECK (char_length(mini_review) <= 500);

COMMENT ON COLUMN reading_sessions.mood IS
  'Humor do leitor ao final da sessão (opcional)';
COMMENT ON COLUMN reading_sessions.mini_review IS
  'Impressão rápida daquela sessão — base para o Diário do Livro (V3). Máx. 500 chars.';

-- ── M-04: origem do livro na biblioteca ──────────────────────
-- Registra quando o livro foi adicionado a partir de um clube.
ALTER TABLE books
  ADD COLUMN IF NOT EXISTS source_club_id UUID
    REFERENCES book_clubs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_books_source_club
  ON books(source_club_id)
  WHERE source_club_id IS NOT NULL;

COMMENT ON COLUMN books.source_club_id IS
  'Quando preenchido, indica que o livro foi adicionado a partir deste clube.';
