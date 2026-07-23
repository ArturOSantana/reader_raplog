-- ============================================================
-- Backfill: marca onboarding_completed = true para perfis que
-- já tinham atividade no app antes desta feature existir.
--
-- Critério: perfil tem pelo menos um livro cadastrado OU uma
-- sessão de leitura OU campos de perfil preenchidos (nome ou
-- gênero favorito). Quem não se encaixa em nenhum critério é
-- genuinamente um novo usuário sem uso e deve ver o onboarding.
-- ============================================================

UPDATE profiles
SET onboarding_completed = TRUE
WHERE onboarding_completed = FALSE
  AND (
    -- Tem livros cadastrados
    id IN (SELECT DISTINCT user_id FROM books)
    -- Tem sessões de leitura
    OR id IN (SELECT DISTINCT user_id FROM reading_sessions)
    -- Tem perfil minimamente preenchido (nome ou gênero)
    OR name IS NOT NULL
    OR favorite_genre IS NOT NULL
  );
