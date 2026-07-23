-- Adiciona coluna de capa do livro atual ao clube
-- Necessário para exibir a thumbnail do livro corrente no card do clube.

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS current_book_cover_url TEXT;
