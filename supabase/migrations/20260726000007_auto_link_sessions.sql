-- ============================================================
-- READLOG — Múltiplos Desafios: auto_link_sessions (F-05)
-- Controla se sessões de leitura contam automaticamente
-- para o desafio (TRUE) ou se exige check-in manual (FALSE).
-- ============================================================

-- ── 1. Coluna em club_challenges ─────────────────────────────
ALTER TABLE club_challenges
  ADD COLUMN IF NOT EXISTS auto_link_sessions BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN club_challenges.auto_link_sessions IS
  'TRUE = qualquer sessão de leitura no período do desafio conta automaticamente. '
  'FALSE = membro deve fazer check-in manual via ClubCheckinScreen.';

-- ── 2. Tabela de check-ins manuais ───────────────────────────
-- Usada apenas quando auto_link_sessions = FALSE.
-- Quando TRUE, o progresso é calculado diretamente de reading_sessions.
CREATE TABLE IF NOT EXISTS challenge_manual_checkins (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id   UUID        NOT NULL REFERENCES club_challenges(id) ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  checkin_date   DATE        NOT NULL DEFAULT CURRENT_DATE,
  pages_read     INTEGER     NOT NULL DEFAULT 0 CHECK (pages_read >= 0),
  minutes_read   INTEGER     NOT NULL DEFAULT 0 CHECK (minutes_read >= 0),
  mood           TEXT        CHECK (mood IN ('great', 'ok', 'tired')),
  photo_url      TEXT,
  caption        TEXT        CHECK (char_length(caption) <= 500),
  feed_item_id   UUID        REFERENCES social_feed(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Um check-in por dia por usuário por desafio
  UNIQUE (challenge_id, user_id, checkin_date)
);

CREATE INDEX IF NOT EXISTS idx_manual_checkins_challenge
  ON challenge_manual_checkins(challenge_id, checkin_date DESC);

CREATE INDEX IF NOT EXISTS idx_manual_checkins_user
  ON challenge_manual_checkins(user_id, checkin_date DESC);

ALTER TABLE challenge_manual_checkins ENABLE ROW LEVEL SECURITY;

-- Membros do clube veem todos os check-ins (para o feed)
CREATE POLICY "manual_checkins: member select"
  ON challenge_manual_checkins FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM club_challenges cc
      WHERE cc.id = challenge_id
        AND is_club_member(cc.club_id, auth.uid())
    )
  );

CREATE POLICY "manual_checkins: self insert"
  ON challenge_manual_checkins FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_challenges cc
      WHERE cc.id = challenge_id
        AND cc.status = 'active'
        AND cc.auto_link_sessions = FALSE
        AND is_club_member(cc.club_id, auth.uid())
    )
  );

-- Membro pode editar o próprio check-in do dia atual
CREATE POLICY "manual_checkins: self update"
  ON challenge_manual_checkins FOR UPDATE
  USING (
    auth.uid() = user_id
    AND checkin_date = CURRENT_DATE
  );

GRANT SELECT, INSERT, UPDATE ON TABLE challenge_manual_checkins TO authenticated;
