-- ============================================================
-- A tabela book_clubs foi criada com o schema base (_003) sem
-- as colunas adicionadas pela migration _010 (book_clubs_v2).
-- Esta migration adiciona as colunas que o app Flutter espera.
-- ============================================================

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS status        TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'on_vacation', 'closed')),
  ADD COLUMN IF NOT EXISTS closed_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visibility    TEXT NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('public', 'private')),
  ADD COLUMN IF NOT EXISTS invite_code   TEXT,
  ADD COLUMN IF NOT EXISTS max_admins    INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS admins_can_promote BOOLEAN NOT NULL DEFAULT FALSE;

-- Índice único para invite_code
CREATE UNIQUE INDEX IF NOT EXISTS idx_book_clubs_invite_code
  ON book_clubs(invite_code)
  WHERE invite_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_book_clubs_status ON book_clubs(status);

-- Preenche invite_code para clubes já existentes sem código
UPDATE book_clubs
SET invite_code = upper(
  substring(translate(gen_random_uuid()::text, '-', ''), 1, 4) || '-' ||
  substring(translate(gen_random_uuid()::text, '-', ''), 1, 4)
)
WHERE invite_code IS NULL;
