-- ============================================================
-- A coluna `username` foi criada com NOT NULL no schema inicial
-- mas o app Flutter não a utiliza (usa `name` em seu lugar).
-- Remove a constraint NOT NULL para que o backfill e o trigger
-- de auto-criação de perfis possam inserir linhas sem username.
-- ============================================================

ALTER TABLE profiles
  ALTER COLUMN username DROP NOT NULL;
