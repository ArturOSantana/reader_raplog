-- ============================================================
-- READLOG — Encerramento automático de votações livres expiradas
-- ============================================================
-- A função close_expired_polls() é chamada de duas formas:
--   1. Via Supabase Edge Function `close-expired-polls` (agendada)
--   2. Via pg_cron diretamente (alternativa sem Edge Function)
--
-- Encerra todas as polls onde closes_at <= NOW() e status = 'open',
-- publica evento 'poll_closed' no feed de cada clube afetado e
-- retorna os registros afetados para a Edge Function logar/notificar.
-- ============================================================

CREATE OR REPLACE FUNCTION close_expired_polls()
RETURNS TABLE(
  poll_id   UUID,
  club_id   UUID,
  question  TEXT,
  closed_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Encerra as polls vencidas
  WITH expired AS (
    UPDATE club_open_polls
    SET status = 'closed'
    WHERE status    = 'open'
      AND closes_at IS NOT NULL
      AND closes_at <= NOW()
    RETURNING id, club_id, question, created_by, NOW() AS closed_at
  )
  -- Publica evento no feed de cada clube                       
  INSERT INTO social_feed (user_id, event_type, club_id, book_title)
  SELECT created_by, 'poll_closed', club_id, question
  FROM expired;

  -- Retorna os registros encerrados para a Edge Function
  RETURN QUERY
    SELECT op.id, op.club_id, op.question, op.closes_at
    FROM club_open_polls op
    WHERE op.status    = 'closed'
      AND op.closes_at IS NOT NULL
      AND op.closes_at >= NOW() - INTERVAL '16 minutes' -- janela de execução da Edge Fn
    ORDER BY op.closes_at DESC;
END;
$$;

-- Apenas service_role chama esta função (via Edge Function ou pg_cron)
REVOKE EXECUTE ON FUNCTION close_expired_polls() FROM authenticated;
GRANT  EXECUTE ON FUNCTION close_expired_polls() TO service_role;

-- Agendamento via pg_cron (fallback caso não use Edge Function)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'close-expired-polls',    -- nome idempotente
      '*/15 * * * *',           -- a cada 15 minutos
      'SELECT close_expired_polls()'
    );
  END IF;
END;
$$;
