-- ============================================================
-- READLOG — Apostas: cancelamento + encerramento automático
-- ============================================================

-- ── 1. RPC: cancelar aposta sem definir vencedor ─────────────
-- Disponível para o criador da aposta ou manager do clube.
-- Muda status para 'closed' sem winner_side, publicando no feed.
CREATE OR REPLACE FUNCTION cancel_bet(p_bet_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id     UUID;
  v_description TEXT;
  v_created_by  UUID;
BEGIN
  SELECT club_id, description, created_by
  INTO v_club_id, v_description, v_created_by
  FROM club_bets WHERE id = p_bet_id AND status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Aposta não encontrada ou já encerrada';
  END IF;

  IF NOT (auth.uid() = v_created_by OR is_club_manager(v_club_id, auth.uid())) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE club_bets
  SET status      = 'closed',
      resolved_at = NOW(),
      resolved_by = auth.uid()
  WHERE id = p_bet_id;

  INSERT INTO social_feed (user_id, event_type, club_id, book_title)
  VALUES (
    auth.uid(),
    'bet_resolved',
    v_club_id,
    'Aposta cancelada: ' || v_description
  );
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_bet(UUID) TO authenticated;

-- ── 2. Trigger: fechar apostas quando resolves_at é atingido ─
-- Usa pg_cron (disponível no Supabase) para rodar a cada hora.
-- Se pg_cron não estiver habilitado, o trigger de UPDATE serve
-- como fallback ao consultar apostas abertas.

CREATE OR REPLACE FUNCTION auto_close_expired_bets()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE club_bets
  SET status      = 'closed',
      resolved_at = NOW()
  WHERE status     = 'open'
    AND resolves_at IS NOT NULL
    AND resolves_at <= NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION auto_close_expired_bets() TO authenticated;

-- Agenda execução a cada hora via pg_cron (requer extensão habilitada no projeto Supabase).
-- Caso pg_cron não esteja disponível, remova ou comente o bloco abaixo.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'auto-close-expired-bets',   -- nome do job (idempotente)
      '0 * * * *',                 -- a cada hora
      'SELECT auto_close_expired_bets()'
    );
  END IF;
END;
$$;

-- ── 3. Trigger inline: ao SELECT de apostas abertas expiradas ─
-- Garante que a expiração seja aplicada mesmo sem pg_cron,
-- sempre que a tabela for consultada via RLS. Usa BEFORE SELECT
-- não é suportado no Postgres — usamos uma função de conveniência
-- que o app chama ao listar apostas do clube.
CREATE OR REPLACE FUNCTION refresh_expired_bets(p_club_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  UPDATE club_bets
  SET status      = 'closed',
      resolved_at = NOW()
  WHERE club_id    = p_club_id
    AND status     = 'open'
    AND resolves_at IS NOT NULL
    AND resolves_at <= NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION refresh_expired_bets(UUID) TO authenticated;
