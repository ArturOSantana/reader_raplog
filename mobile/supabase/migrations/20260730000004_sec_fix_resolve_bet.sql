-- ============================================================
-- SEC-FIX P1-B: Refatora resolve_bet para não concatenar texto
--               do usuário no social_feed
--
-- Problema: resolve_bet() inseria no feed:
--   'Aposta: ' || v_description || ' — Vencedor: ' || v_winner_label
-- reutilizando o campo book_title (semântica errada) e
-- propagando texto do usuário sem sanitização.
--
-- Correção:
--   1. Adiciona coluna bet_id UUID em social_feed (referência)
--   2. Reescreve resolve_bet() para inserir apenas a FK —
--      o cliente monta o texto a partir dos dados estruturados
--   3. Mantém backward-compat: book_title continua existindo
--      para outros event_types, apenas não é mais usado aqui
-- ============================================================

-- 1. Adiciona coluna referencial em social_feed
ALTER TABLE social_feed
  ADD COLUMN IF NOT EXISTS bet_id UUID
    REFERENCES club_bets(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_social_feed_bet_id
  ON social_feed(bet_id)
  WHERE bet_id IS NOT NULL;

-- 2. Reescreve resolve_bet() — sem concatenação de texto livre
CREATE OR REPLACE FUNCTION resolve_bet(
  p_bet_id      UUID,
  p_winner_side TEXT   -- 'a' | 'b'
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_created_by UUID;
BEGIN
  -- Carrega apenas o que é necessário (sem description/labels no scope)
  SELECT club_id, created_by
  INTO   v_club_id, v_created_by
  FROM   club_bets
  WHERE  id = p_bet_id AND status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Aposta não encontrada ou já resolvida';
  END IF;

  IF NOT (auth.uid() = v_created_by OR is_club_manager(v_club_id, auth.uid())) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  IF p_winner_side NOT IN ('a', 'b') THEN
    RAISE EXCEPTION 'winner_side deve ser ''a'' ou ''b''';
  END IF;

  -- Atualiza o status da aposta
  UPDATE club_bets
  SET status      = 'resolved',
      winner_side = p_winner_side,
      resolved_at = NOW(),
      resolved_by = auth.uid()
  WHERE id = p_bet_id;

  -- Publica no feed com referência estrutural — SEM concatenação de texto
  INSERT INTO social_feed (user_id, event_type, club_id, bet_id)
  VALUES (auth.uid(), 'bet_resolved', v_club_id, p_bet_id);
END;
$$;

GRANT EXECUTE ON FUNCTION resolve_bet(UUID, TEXT) TO authenticated;
