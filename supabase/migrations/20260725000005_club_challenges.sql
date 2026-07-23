-- ============================================================
-- READLOG — Desafio do Clube (M-09)
-- Metas coletivas com progresso individual rastreado em tempo
-- real via reading_sessions existentes.
-- ============================================================

-- ── 1. Tabela de desafios ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS club_challenges (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id      UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  created_by   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  description  TEXT,
  goal_type    TEXT        NOT NULL
                CHECK (goal_type IN (
                  'pages',        -- total de páginas lidas no período
                  'minutes',      -- total de minutos lidos
                  'checkins',     -- dias com pelo menos 1 sessão concluída
                  'sessions'      -- número de sessões
                )),
  goal_value   INTEGER     NOT NULL CHECK (goal_value > 0),
  starts_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at      TIMESTAMPTZ NOT NULL,
  status       TEXT        NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'finished', 'cancelled')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_club_challenges_club
  ON club_challenges(club_id, status, ends_at DESC);

ALTER TABLE club_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "challenges: member select"
  ON club_challenges FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

CREATE POLICY "challenges: manager insert"
  ON club_challenges FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

CREATE POLICY "challenges: manager update"
  ON club_challenges FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE ON TABLE club_challenges TO authenticated;

-- ── 2. RPC: progresso do usuário no desafio ──────────────────
-- Calcula o progresso individual usando reading_sessions já existentes.
-- Não precisa de tabela separada de participantes — qualquer membro
-- que ler no período já está "participando".
CREATE OR REPLACE FUNCTION club_challenge_progress(p_challenge_id UUID)
RETURNS TABLE (
  user_id       UUID,
  user_name     TEXT,
  avatar_url    TEXT,
  current_value BIGINT,          -- páginas / minutos / check-ins / sessões
  goal_value    INTEGER,
  pct_complete  NUMERIC,         -- 0–100
  rank          INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_goal_type  TEXT;
  v_goal_value INTEGER;
  v_starts_at  TIMESTAMPTZ;
  v_ends_at    TIMESTAMPTZ;
BEGIN
  SELECT club_id, goal_type, c.goal_value, starts_at, ends_at
  INTO v_club_id, v_goal_type, v_goal_value, v_starts_at, v_ends_at
  FROM club_challenges c WHERE c.id = p_challenge_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  WITH raw AS (
    SELECT
      bcm.user_id,
      p.name        AS user_name,
      p.avatar_url,
      CASE v_goal_type
        WHEN 'pages'    THEN COALESCE(SUM(rs.pages_read), 0)
        WHEN 'minutes'  THEN COALESCE(SUM(rs.duration_minutes), 0)
        WHEN 'sessions' THEN COUNT(DISTINCT rs.id)
        WHEN 'checkins' THEN COUNT(DISTINCT DATE(rs.started_at AT TIME ZONE 'UTC'))
      END AS current_value
    FROM book_club_members bcm
    JOIN profiles p ON p.id = bcm.user_id
    LEFT JOIN reading_sessions rs
      ON rs.user_id   = bcm.user_id
     AND rs.status    = 'finished'
     AND rs.started_at >= v_starts_at
     AND rs.started_at <  v_ends_at
    WHERE bcm.club_id = v_club_id
    GROUP BY bcm.user_id, p.name, p.avatar_url
  )
  SELECT
    raw.user_id,
    raw.user_name,
    raw.avatar_url,
    raw.current_value,
    v_goal_value,
    LEAST(ROUND(raw.current_value::NUMERIC / v_goal_value * 100, 1), 100) AS pct_complete,
    ROW_NUMBER() OVER (ORDER BY raw.current_value DESC, raw.user_name ASC)::INTEGER AS rank
  FROM raw
  ORDER BY raw.current_value DESC, raw.user_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_challenge_progress(UUID) TO authenticated;

-- ── 3. Trigger: notifica ao criar desafio ────────────────────
CREATE OR REPLACE FUNCTION notify_new_challenge()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM notify_club_members(
    NEW.club_id,
    'clubs',
    'new_challenge',
    'Novo desafio no clube!',
    NEW.title,
    '/clubs/' || NEW.club_id || '/challenges',
    NEW.created_by
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_challenge ON club_challenges;
CREATE TRIGGER trg_notify_new_challenge
  AFTER INSERT ON club_challenges
  FOR EACH ROW EXECUTE FUNCTION notify_new_challenge();
