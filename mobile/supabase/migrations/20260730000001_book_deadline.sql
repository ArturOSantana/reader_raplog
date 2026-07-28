-- ============================================================
-- READLOG — Prazo de leitura por livro (book deadline)
-- ============================================================
-- Regras:
--   1. Qualquer livro pode ter um `deadline` (DATE, opcional).
--   2. Todo dia às 02:00 UTC: livros com deadline vencido que não
--      tenham status 'read' são marcados como 'abandoned' e a caixa
--      de entrada do usuário recebe uma notificação.
--   3. Um dia antes do deadline, o usuário recebe um aviso antecipado.
-- ============================================================

-- ── 1. Coluna deadline na tabela books ───────────────────────

ALTER TABLE books
  ADD COLUMN IF NOT EXISTS deadline DATE;

COMMENT ON COLUMN books.deadline IS
  'Prazo opcional para finalizar o livro. Livros não concluídos até esta data são movidos para "abandoned" automaticamente.';

-- ── 2. Função: expirar livros vencidos ───────────────────────

CREATE OR REPLACE FUNCTION expire_overdue_books()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT id, user_id, title
    FROM books
    WHERE deadline IS NOT NULL
      AND deadline < CURRENT_DATE
      AND status NOT IN ('read', 'abandoned')
  LOOP
    -- Marca como abandonado
    UPDATE books
    SET status     = 'abandoned',
        updated_at = NOW()
    WHERE id = rec.id;

    -- Notifica o usuário
    INSERT INTO notification_items (user_id, category, title, body)
    VALUES (
      rec.user_id,
      'reading',
      '📚 Livro movido para Abandonado',
      'O prazo de leitura de "' || rec.title || '" expirou e ele foi movido para Abandonado. Você pode retomá-lo quando quiser!'
    );
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION expire_overdue_books() FROM authenticated;
GRANT  EXECUTE ON FUNCTION expire_overdue_books() TO service_role;

-- ── 3. Função: notificar usuários com prazo amanhã ───────────

CREATE OR REPLACE FUNCTION notify_book_deadline_tomorrow()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT id, user_id, title
    FROM books
    WHERE deadline IS NOT NULL
      AND deadline = CURRENT_DATE + INTERVAL '1 day'
      AND status NOT IN ('read', 'abandoned')
  LOOP
    -- Evita duplicar aviso no mesmo dia (checa se já existe notif igual hoje)
    IF NOT EXISTS (
      SELECT 1 FROM notification_items
      WHERE user_id    = rec.user_id
        AND category   = 'reading'
        AND title      = '⏰ Prazo de leitura amanhã'
        AND body       LIKE '%' || rec.title || '%'
        AND created_at >= CURRENT_DATE
    ) THEN
      INSERT INTO notification_items (user_id, category, title, body)
      VALUES (
        rec.user_id,
        'reading',
        '⏰ Prazo de leitura amanhã',
        'Falta apenas 1 dia para o prazo de "' || rec.title || '". Finalize a leitura para não ir para Abandonado!'
      );
    END IF;
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION notify_book_deadline_tomorrow() FROM authenticated;
GRANT  EXECUTE ON FUNCTION notify_book_deadline_tomorrow() TO service_role;

-- ── 4. pg_cron: agendamento diário ───────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Expira livros vencidos todo dia às 02:00 UTC
    PERFORM cron.schedule(
      'expire-overdue-books',
      '0 2 * * *',
      'SELECT expire_overdue_books()'
    );
    -- Notifica prazo de amanhã todo dia às 09:00 UTC
    PERFORM cron.schedule(
      'notify-book-deadline-tomorrow',
      '0 9 * * *',
      'SELECT notify_book_deadline_tomorrow()'
    );
  END IF;
END;
$$;
