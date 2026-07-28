-- ============================================================
-- READLOG V2 — Selos, Clube Verificado e Tipo de Encontro
-- ============================================================

-- ── 1. book_clubs.is_verified ─────────────────────────────────────────────────
-- Apenas service_role pode marcar um clube como verificado.
-- O UPDATE policy é restringido intencionalmente — não é uma ação de usuário comum.

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_book_clubs_is_verified
  ON book_clubs(is_verified) WHERE is_verified = TRUE;

-- ── 2. book_club_meetings.meeting_type ───────────────────────────────────────
-- Diferencia tipos de encontro (discussão, leitura compartilhada, virtual, outro).
-- O valor 'shared_reading' habilita a lógica de contagem para ofensiva coletiva (V2).

ALTER TABLE book_club_meetings
  ADD COLUMN IF NOT EXISTS meeting_type TEXT NOT NULL DEFAULT 'discussion'
  CHECK (meeting_type IN ('discussion', 'shared_reading', 'virtual', 'other'));

-- ── 3. club_seals — Selos distribuídos pelo admin ────────────────────────────
--
-- Selos são atribuídos manualmente por admins/owners.
-- Substituem o "Melhor Comentário / Melhor Reflexão" automático removido do
-- Hall da Fama na spec (seção 2 da spec consolidada).
--
-- Tipos pré-definidos (extensível — guard pelo CHECK ou por aplicação):
--   'best_reader'      Leitor do Ciclo
--   'best_reviewer'    Melhor Resenha
--   'most_consistent'  Mais Consistente
--   'best_comment'     Melhor Comentário
--   'most_engaged'     Mais Engajado
--   'challenge_winner' Vencedor do Desafio
--   'custom'           Personalizado (texto livre em description)

CREATE TABLE IF NOT EXISTS club_seals (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID        NOT NULL REFERENCES book_clubs(id)     ON DELETE CASCADE,
  awarded_to    UUID        NOT NULL REFERENCES auth.users(id)     ON DELETE CASCADE,
  awarded_by    UUID        NOT NULL REFERENCES auth.users(id)     ON DELETE CASCADE,
  seal_type     TEXT        NOT NULL
                              CHECK (seal_type IN (
                                'best_reader', 'best_reviewer', 'most_consistent',
                                'best_comment', 'most_engaged', 'challenge_winner', 'custom'
                              )),
  description   TEXT,                             -- usado quando seal_type = 'custom' ou detalhe extra
  book_history_id UUID      REFERENCES club_book_history(id) ON DELETE SET NULL,
  challenge_id  UUID        REFERENCES club_challenges(id)   ON DELETE SET NULL,
  awarded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_seals_club
  ON club_seals(club_id, awarded_at DESC);

CREATE INDEX IF NOT EXISTS idx_club_seals_user
  ON club_seals(awarded_to, club_id);

ALTER TABLE club_seals ENABLE ROW LEVEL SECURITY;

-- Membros veem os selos do clube
CREATE POLICY "seals: member select"
  ON club_seals FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Apenas managers (owner/admin) distribuem selos
CREATE POLICY "seals: manager insert"
  ON club_seals FOR INSERT
  WITH CHECK (
    auth.uid() = awarded_by
    AND is_club_manager(club_id, auth.uid())
  );

-- Manager pode revogar (apagar) um selo
CREATE POLICY "seals: manager delete"
  ON club_seals FOR DELETE
  USING (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, DELETE ON TABLE club_seals TO authenticated;

-- ── 4. View auxiliar: selos por membro no clube ───────────────────────────────
-- Retorna lista de selos com nome do agraciado e do concedente.
CREATE OR REPLACE VIEW club_seals_view AS
SELECT
  cs.id,
  cs.club_id,
  cs.seal_type,
  cs.description,
  cs.awarded_at,
  cs.book_history_id,
  cs.challenge_id,
  -- Agraciado
  cs.awarded_to,
  p_to.name   AS awarded_to_name,
  p_to.avatar_url AS awarded_to_avatar,
  -- Concedente
  cs.awarded_by,
  p_by.name   AS awarded_by_name
FROM club_seals cs
LEFT JOIN profiles p_to ON p_to.id = cs.awarded_to
LEFT JOIN profiles p_by ON p_by.id = cs.awarded_by;

GRANT SELECT ON club_seals_view TO authenticated;

-- ── 5. Evento no feed ao distribuir um selo ───────────────────────────────────
-- Adiciona event_type 'seal_awarded' ao CHECK do social_feed.

ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_event_type_check;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_event_type_check
  CHECK (event_type IN (
    'finished_book', 'started_book', 'streak', 'achievement',
    'goal_completed', 'reading_session', 'joined_club',
    'bet_resolved', 'poll_opened', 'poll_closed',
    'challenge_started', 'challenge_finished',
    'seal_awarded'
  ));

-- Trigger: publica no feed do clube ao distribuir um selo
CREATE OR REPLACE FUNCTION fn_seal_awarded_feed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_recipient_name TEXT;
BEGIN
  SELECT name INTO v_recipient_name FROM profiles WHERE id = NEW.awarded_to;

  INSERT INTO social_feed (
    user_id, event_type, club_id, book_title
  ) VALUES (
    NEW.awarded_by,
    'seal_awarded',
    NEW.club_id,
    -- Reutilizamos book_title para carregar o nome do agraciado + tipo de selo
    v_recipient_name || ' · ' || NEW.seal_type
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_seal_awarded_feed
  AFTER INSERT ON club_seals
  FOR EACH ROW EXECUTE FUNCTION fn_seal_awarded_feed();
