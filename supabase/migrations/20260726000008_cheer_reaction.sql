-- ============================================================
-- READLOG — Cheer Rápido no Check-in (F-06)
-- Adiciona o tipo 'cheer' à tabela feed_reactions existente.
-- O cheer é uma reação de 1 toque, leve e sem fricção.
-- ============================================================

-- ── 1. Adiciona 'cheer' ao CHECK constraint ───────────────────
-- A constraint existente em feed_reactions.reaction_type precisa
-- ser substituída para incluir o novo tipo.
ALTER TABLE feed_reactions
  DROP CONSTRAINT IF EXISTS feed_reactions_reaction_type_check;

ALTER TABLE feed_reactions
  ADD CONSTRAINT feed_reactions_reaction_type_check
  CHECK (reaction_type IN (
    'heart',
    'book',
    'fire',
    'clap',
    'brain',
    'coffee',
    'love_eyes',
    'cheer'
  ));

-- ── 2. RPC: dar/remover cheer (toggle) ────────────────────────
-- Abstração de conveniência para o botão de 1 toque.
-- Retorna TRUE se o cheer foi adicionado, FALSE se foi removido.
CREATE OR REPLACE FUNCTION toggle_cheer(p_feed_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Verifica se o caller tem acesso ao post
  IF NOT EXISTS (
    SELECT 1 FROM social_feed sf
    WHERE sf.id = p_feed_id
      AND (
        sf.club_id IS NULL
        OR is_club_member(sf.club_id, auth.uid())
      )
  ) THEN
    RAISE EXCEPTION 'Post não encontrado ou sem acesso';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM feed_reactions
    WHERE feed_id = p_feed_id
      AND user_id = auth.uid()
      AND reaction_type = 'cheer'
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM feed_reactions
    WHERE feed_id = p_feed_id
      AND user_id = auth.uid()
      AND reaction_type = 'cheer';
    RETURN FALSE;
  ELSE
    -- Não permite cheer no próprio post
    IF EXISTS (SELECT 1 FROM social_feed WHERE id = p_feed_id AND user_id = auth.uid()) THEN
      RETURN FALSE;
    END IF;

    INSERT INTO feed_reactions (feed_id, user_id, reaction_type)
    VALUES (p_feed_id, auth.uid(), 'cheer')
    ON CONFLICT DO NOTHING;
    RETURN TRUE;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION toggle_cheer(UUID) TO authenticated;
