-- ============================================================
-- READLOG V3 — Selos Personalizáveis + Validade de 1 mês
-- ============================================================

-- 1. Adiciona campos de personalização visual
-- Nota: GENERATED ALWAYS AS não pode ser usado com TIMESTAMPTZ porque a
-- expressão (awarded_at + INTERVAL) não é imutável (depende do timezone da
-- sessão). expires_at é coluna regular preenchida pelo trigger abaixo.
ALTER TABLE club_seals
  ADD COLUMN IF NOT EXISTS custom_emoji  TEXT,    -- emoji personalizado (substitui o padrão do tipo)
  ADD COLUMN IF NOT EXISTS custom_label  TEXT,    -- título personalizado (substitui label do tipo)
  ADD COLUMN IF NOT EXISTS expires_at    TIMESTAMPTZ; -- preenchido pelo trigger set_seal_expires_at

-- Trigger que preenche expires_at = awarded_at + 1 mês em INSERT/UPDATE
CREATE OR REPLACE FUNCTION _set_seal_expires_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.expires_at := NEW.awarded_at + INTERVAL '1 month';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_seal_expires_at ON club_seals;
CREATE TRIGGER trg_seal_expires_at
  BEFORE INSERT OR UPDATE OF awarded_at ON club_seals
  FOR EACH ROW EXECUTE FUNCTION _set_seal_expires_at();

-- Preenche retroativamente os registros existentes
UPDATE club_seals SET expires_at = awarded_at + INTERVAL '1 month' WHERE expires_at IS NULL;

-- 2. Atualiza a view para incluir os novos campos
-- DROP necessário: CREATE OR REPLACE VIEW não pode alterar a ordem/nome das colunas
DROP VIEW IF EXISTS club_seals_view;
CREATE VIEW club_seals_view AS
SELECT
  cs.id,
  cs.club_id,
  cs.seal_type,
  cs.description,
  cs.custom_emoji,
  cs.custom_label,
  cs.awarded_at,
  cs.expires_at,
  cs.book_history_id,
  cs.challenge_id,
  -- Agraciado
  cs.awarded_to,
  p_to.name       AS awarded_to_name,
  p_to.avatar_url AS awarded_to_avatar,
  -- Concedente
  cs.awarded_by,
  p_by.name       AS awarded_by_name
FROM club_seals cs
LEFT JOIN profiles p_to ON p_to.id = cs.awarded_to
LEFT JOIN profiles p_by ON p_by.id = cs.awarded_by;

GRANT SELECT ON club_seals_view TO authenticated;
