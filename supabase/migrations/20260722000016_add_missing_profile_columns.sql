-- ============================================================
-- A tabela profiles foi criada a partir do schema.sql original
-- com apenas: id, username, avatar_url, created_at, updated_at.
-- A migration _001 usou CREATE TABLE IF NOT EXISTS e foi pulada.
-- Esta migration adiciona as colunas que o app Flutter espera.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS name             TEXT,
  ADD COLUMN IF NOT EXISTS bio              TEXT,
  ADD COLUMN IF NOT EXISTS yearly_goal      INTEGER CHECK (yearly_goal > 0),
  ADD COLUMN IF NOT EXISTS favorite_genre   TEXT,
  ADD COLUMN IF NOT EXISTS favorite_authors TEXT,
  ADD COLUMN IF NOT EXISTS favorite_book    TEXT;
