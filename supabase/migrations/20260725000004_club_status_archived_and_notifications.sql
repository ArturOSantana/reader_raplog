-- ============================================================
-- READLOG — Estado "Arquivado" (M-07) +
--           Notificações in-app de Clube (M-03)
-- ============================================================

-- ── M-07: status 'archived' no clube ─────────────────────────
-- Diferente de 'closed': arquivado = somente leitura, histórico
-- preservado, sem prazo de exclusão.
ALTER TABLE book_clubs
  DROP CONSTRAINT IF EXISTS book_clubs_status_check;

ALTER TABLE book_clubs
  ADD CONSTRAINT book_clubs_status_check
  CHECK (status IN ('active', 'on_vacation', 'closed', 'archived'));

-- ── M-03: notificações in-app com referência ao clube ────────
-- Adiciona club_id + action_url para deep link + event_type
-- detalhado para filtragem no cliente.

ALTER TABLE notification_items
  ADD COLUMN IF NOT EXISTS club_id    UUID REFERENCES book_clubs(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS event_type TEXT,   -- tipo detalhado dentro da categoria
  ADD COLUMN IF NOT EXISTS action_url TEXT;   -- deep link: /clubs/:id ou /clubs/:id/feed etc.

CREATE INDEX IF NOT EXISTS idx_notification_items_club
  ON notification_items(club_id)
  WHERE club_id IS NOT NULL;

-- ── RPC: criar notificação para todos os membros de um clube ──
-- Chamado por triggers ou Edge Functions para notificar um evento.
CREATE OR REPLACE FUNCTION notify_club_members(
  p_club_id    UUID,
  p_category   TEXT,
  p_event_type TEXT,
  p_title      TEXT,
  p_body       TEXT,
  p_action_url TEXT DEFAULT NULL,
  p_exclude_user UUID DEFAULT NULL   -- não notifica quem gerou o evento
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO notification_items (user_id, category, event_type, title, body, club_id, action_url)
  SELECT
    bcm.user_id,
    p_category,
    p_event_type,
    p_title,
    p_body,
    p_club_id,
    p_action_url
  FROM book_club_members bcm
  WHERE bcm.club_id = p_club_id
    AND (p_exclude_user IS NULL OR bcm.user_id != p_exclude_user);
END;
$$;

GRANT EXECUTE ON FUNCTION notify_club_members(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;

-- ── Trigger: notifica membros quando uma votação de livro é aberta ──
CREATE OR REPLACE FUNCTION notify_new_poll()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM notify_club_members(
    NEW.club_id,
    'clubs',
    'new_poll',
    'Nova votação no clube',
    NEW.title,
    '/clubs/' || NEW.club_id || '/polls',
    NEW.created_by
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_poll ON club_book_polls;
CREATE TRIGGER trg_notify_new_poll
  AFTER INSERT ON club_book_polls
  FOR EACH ROW EXECUTE FUNCTION notify_new_poll();

-- ── Trigger: notifica quando ofensiva coletiva fica em risco ─
-- "Em risco" = ninguém leu hoje ainda. Chamado por Edge Function
-- pg_cron diariamente às 20h — aqui apenas a função.
CREATE OR REPLACE FUNCTION notify_streak_at_risk(p_club_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_anyone_read_today BOOLEAN;
  v_club_name         TEXT;
BEGIN
  SELECT name INTO v_club_name FROM book_clubs WHERE id = p_club_id;

  SELECT EXISTS (
    SELECT 1
    FROM reading_sessions rs
    JOIN book_club_members bcm ON bcm.user_id = rs.user_id
    WHERE bcm.club_id = p_club_id
      AND DATE(rs.started_at AT TIME ZONE 'UTC') = CURRENT_DATE
      AND rs.status = 'finished'
  ) INTO v_anyone_read_today;

  IF NOT v_anyone_read_today THEN
    PERFORM notify_club_members(
      p_club_id,
      'clubs',
      'streak_at_risk',
      'Ofensiva em risco!',
      'Ninguém leu hoje no ' || v_club_name || '. Seja o primeiro!',
      '/clubs/' || p_club_id
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION notify_streak_at_risk(UUID) TO authenticated;
