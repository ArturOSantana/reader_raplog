-- Adiciona autores favoritos e livro favorito ao perfil
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS favorite_authors TEXT,
  ADD COLUMN IF NOT EXISTS favorite_book    TEXT;
