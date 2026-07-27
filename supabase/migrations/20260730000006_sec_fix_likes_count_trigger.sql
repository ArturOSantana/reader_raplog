-- ============================================================
-- SEC-FIX P2-B: Corrige race condition em likes_count
--
-- Problema: O trigger trg_feed_likes_count era FOR EACH STATEMENT,
-- o que significa que em múltiplas operações concorrentes,
-- apenas o último UPDATE "vence" e os outros se perdem —
-- causando likes_count dessincronizado.
--
-- Correção:
--   1. Recria o trigger como FOR EACH ROW (dispara por linha
--      afetada, garantindo que cada operação seja tratada)
--   2. Adiciona SET search_path = public (estava faltando)
--   3. A lógica de UPDATE com subquery COUNT(*) já é atômica
--      dentro da transação — SELECT FOR UPDATE não é necessário
--      pois o UPDATE no Postgres faz row-level lock implícito
--      na linha do social_feed que está sendo atualizada
-- ============================================================

-- Remove a função e trigger antigos
DROP TRIGGER IF EXISTS trg_feed_likes_count ON feed_likes;
DROP FUNCTION IF EXISTS refresh_feed_likes_count();

-- Recria a função com FOR EACH ROW e search_path correto
CREATE OR REPLACE FUNCTION refresh_feed_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_feed_id UUID;
BEGIN
  -- Para INSERT: usa NEW; para DELETE: usa OLD
  v_feed_id := COALESCE(NEW.feed_id, OLD.feed_id);

  UPDATE social_feed
  SET likes_count = (
    SELECT COUNT(*) FROM feed_likes WHERE feed_id = v_feed_id
  )
  WHERE id = v_feed_id;

  RETURN NULL;
END;
$$;

-- Recria como FOR EACH ROW (elimina a race condition)
CREATE OR REPLACE TRIGGER trg_feed_likes_count
  AFTER INSERT OR DELETE ON feed_likes
  FOR EACH ROW EXECUTE FUNCTION refresh_feed_likes_count();
