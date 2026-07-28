-- ============================================================
-- Campos extras para o perfil público rico do amigo
--   • Privacidade granular (current_book_public, etc.)
--   • Localização e data de entrada (membro desde)
--   • Formato de leitura preferido
--   • Campos de estatísticas denormalizados (opcionais; podem
--     ser calculados on-demand a partir das tabelas de sessões)
-- ============================================================

-- Informações básicas extras
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS location          TEXT,
  ADD COLUMN IF NOT EXISTS member_since      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS username          TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS preferred_format  TEXT CHECK (preferred_format IN ('physical','ebook','both'));

-- Controles de privacidade — cada usuário decide o que expor
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS privacy_current_book    BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_calendar        BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_clubs           BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_wishlist        BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS privacy_library         BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS privacy_activity        BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS privacy_compatibility   BOOLEAN NOT NULL DEFAULT TRUE;

-- Política de leitura pública: qualquer autenticado pode ler perfis alheios
-- (campos sensíveis como e-mail nunca estão na tabela profiles)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'Perfis públicos para autenticados'
  ) THEN
    CREATE POLICY "Perfis públicos para autenticados"
      ON profiles FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- View materializada-light: expõe apenas colunas seguras para amigos
-- Não inclui: e-mail, configurações, dados da conta
CREATE OR REPLACE VIEW public_profile_view AS
SELECT
  id,
  name,
  username,
  bio,
  avatar_url,
  location,
  member_since,
  favorite_genre,
  favorite_authors,
  favorite_book,
  yearly_goal,
  preferred_format,
  privacy_current_book,
  privacy_calendar,
  privacy_clubs,
  privacy_wishlist,
  privacy_library,
  privacy_activity,
  privacy_compatibility
FROM profiles;

-- Garante acesso à view para usuários autenticados
GRANT SELECT ON public_profile_view TO authenticated;
