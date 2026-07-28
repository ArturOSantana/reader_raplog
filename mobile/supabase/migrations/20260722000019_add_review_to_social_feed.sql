-- Adiciona campos de review e tempo de leitura ao feed social
ALTER TABLE social_feed
  ADD COLUMN IF NOT EXISTS review TEXT,
  ADD COLUMN IF NOT EXISTS reading_time_minutes INTEGER;

-- Garante que a coluna seja acessível via RLS existente
-- (a policy já cobre todas as colunas da tabela)
COMMENT ON COLUMN social_feed.review IS 'Pequena resenha escrita pelo usuário ao concluir o livro';
COMMENT ON COLUMN social_feed.reading_time_minutes IS 'Total de minutos gastos lendo o livro, soma das sessões';
