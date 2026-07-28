-- ============================================================
-- READLOG — Apostas Amistosas com Leaderboard (V2/Seção 6) +
--           Votações Livres / Open Polls (V2/Seção 7)
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- PARTE 1 — APOSTAS AMISTOSAS
-- ══════════════════════════════════════════════════════════════

-- ── 1a. Tabela principal de apostas ──────────────────────────
CREATE TABLE IF NOT EXISTS club_bets (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id              UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  created_by           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  description          TEXT        NOT NULL CHECK (char_length(description) BETWEEN 3 AND 300),
  stake_type           TEXT        NOT NULL DEFAULT 'outro'
                         CHECK (stake_type IN ('pizza','cafe','livro','vale_presente','dinheiro_registrado','outro')),
  stake_description    TEXT,                          -- detalhe livre ("café duplo")
  resolution_criteria  TEXT,                          -- como se decide o vencedor
  -- Apostas com 2 lados: sim/não, equipe A/B, etc.
  -- Para N lados: usar bet_sides (JSON)
  side_a_label         TEXT        NOT NULL DEFAULT 'Sim',
  side_b_label         TEXT        NOT NULL DEFAULT 'Não',
  status               TEXT        NOT NULL DEFAULT 'open'
                         CHECK (status IN ('open', 'closed', 'resolved')),
  winner_side          TEXT,                          -- 'a' | 'b' | NULL se empate/cancelado
  resolves_at          TIMESTAMPTZ,
  resolved_at          TIMESTAMPTZ,
  resolved_by          UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_bets_club
  ON club_bets(club_id, status, created_at DESC);

ALTER TABLE club_bets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bets: member select"
  ON club_bets FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

CREATE POLICY "bets: member insert"
  ON club_bets FOR INSERT
  WITH CHECK (auth.uid() = created_by AND is_club_member(club_id, auth.uid()));

-- Apenas quem criou a aposta ou um manager pode atualizar (resolver)
CREATE POLICY "bets: creator or manager update"
  ON club_bets FOR UPDATE
  USING (auth.uid() = created_by OR is_club_manager(club_id, auth.uid()));

-- Apenas manager ou criador pode cancelar
CREATE POLICY "bets: creator or manager delete"
  ON club_bets FOR DELETE
  USING (auth.uid() = created_by OR is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_bets TO authenticated;

-- ── 1b. Participantes da aposta ───────────────────────────────
CREATE TABLE IF NOT EXISTS club_bet_participants (
  bet_id     UUID        NOT NULL REFERENCES club_bets(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  side       TEXT        NOT NULL CHECK (side IN ('a', 'b')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (bet_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_bet_participants_bet
  ON club_bet_participants(bet_id);

CREATE INDEX IF NOT EXISTS idx_bet_participants_user
  ON club_bet_participants(user_id);

ALTER TABLE club_bet_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bet_participants: member select"
  ON club_bet_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id AND is_club_member(cb.club_id, auth.uid())
    )
  );

-- Membro pode entrar numa aposta aberta
CREATE POLICY "bet_participants: self insert"
  ON club_bet_participants FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id
        AND cb.status = 'open'
        AND is_club_member(cb.club_id, auth.uid())
    )
  );

-- Membro pode trocar de lado enquanto aberta
CREATE POLICY "bet_participants: self update"
  ON club_bet_participants FOR UPDATE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id AND cb.status = 'open'
    )
  );

-- Membro pode sair da aposta enquanto aberta
CREATE POLICY "bet_participants: self delete"
  ON club_bet_participants FOR DELETE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id AND cb.status = 'open'
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_bet_participants TO authenticated;

-- ── 1c. RPC: Leaderboard de apostas ──────────────────────────
-- Retorna ranking de acertos por membro no clube.
-- Mínimo de participações configurável para evitar distorção
-- de quem apostou 1 vez e acertou.
CREATE OR REPLACE FUNCTION club_bets_leaderboard(
  p_club_id UUID,
  p_min_bets INTEGER DEFAULT 2   -- mínimo de apostas para entrar no ranking
)
RETURNS TABLE (
  rank              INTEGER,
  user_id           UUID,
  user_name         TEXT,
  avatar_url        TEXT,
  total_bets        BIGINT,
  total_wins        BIGINT,
  total_losses      BIGINT,
  win_rate_pct      NUMERIC       -- 0–100
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  WITH stats AS (
    SELECT
      bp.user_id,
      p.name        AS user_name,
      p.avatar_url,
      COUNT(*)                                                     AS total_bets,
      COUNT(*) FILTER (WHERE cb.winner_side = bp.side)            AS total_wins,
      COUNT(*) FILTER (WHERE cb.winner_side IS NOT NULL
                         AND cb.winner_side != bp.side)           AS total_losses
    FROM club_bet_participants bp
    JOIN club_bets cb ON cb.id = bp.bet_id
    JOIN profiles p   ON p.id  = bp.user_id
    WHERE cb.club_id = p_club_id
      AND cb.status  = 'resolved'
    GROUP BY bp.user_id, p.name, p.avatar_url
    HAVING COUNT(*) >= p_min_bets
  )
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY
        ROUND(total_wins::NUMERIC / NULLIF(total_bets, 0) * 100, 1) DESC,
        total_wins DESC,
        user_name ASC
    )::INTEGER AS rank,
    stats.user_id,
    stats.user_name,
    stats.avatar_url,
    stats.total_bets,
    stats.total_wins,
    stats.total_losses,
    ROUND(stats.total_wins::NUMERIC / NULLIF(stats.total_bets, 0) * 100, 1) AS win_rate_pct
  FROM stats
  ORDER BY win_rate_pct DESC, total_wins DESC, user_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_bets_leaderboard(UUID, INTEGER) TO authenticated;

-- ── 1d. RPC: resolver aposta e publicar no feed ───────────────
CREATE OR REPLACE FUNCTION resolve_bet(
  p_bet_id     UUID,
  p_winner_side TEXT   -- 'a' | 'b'
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id     UUID;
  v_description TEXT;
  v_created_by  UUID;
  v_side_a      TEXT;
  v_side_b      TEXT;
  v_winner_label TEXT;
BEGIN
  SELECT club_id, description, created_by, side_a_label, side_b_label
  INTO v_club_id, v_description, v_created_by, v_side_a, v_side_b
  FROM club_bets WHERE id = p_bet_id AND status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Aposta não encontrada ou já resolvida';
  END IF;

  IF NOT (auth.uid() = v_created_by OR is_club_manager(v_club_id, auth.uid())) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  IF p_winner_side NOT IN ('a', 'b') THEN
    RAISE EXCEPTION 'winner_side deve ser ''a'' ou ''b''';
  END IF;

  v_winner_label := CASE p_winner_side WHEN 'a' THEN v_side_a ELSE v_side_b END;

  UPDATE club_bets
  SET status       = 'resolved',
      winner_side  = p_winner_side,
      resolved_at  = NOW(),
      resolved_by  = auth.uid()
  WHERE id = p_bet_id;

  -- Publica no feed do clube
  INSERT INTO social_feed (user_id, event_type, club_id, book_title)
  VALUES (
    auth.uid(),
    'bet_resolved',
    v_club_id,
    -- Reutilizamos book_title como container de texto (é o campo mais genérico disponível)
    'Aposta: ' || v_description || ' — Vencedor: ' || v_winner_label
  );
END;
$$;

GRANT EXECUTE ON FUNCTION resolve_bet(UUID, TEXT) TO authenticated;

-- Adiciona 'bet_resolved' ao CHECK de event_type do feed
ALTER TABLE social_feed
  DROP CONSTRAINT IF EXISTS social_feed_event_type_check;

ALTER TABLE social_feed
  ADD CONSTRAINT social_feed_event_type_check
  CHECK (event_type IN (
    'finished_book', 'started_book', 'streak', 'achievement',
    'goal_completed', 'reading_session', 'joined_club',
    'bet_resolved', 'poll_opened', 'poll_closed', 'challenge_started'
  ));

-- ══════════════════════════════════════════════════════════════
-- PARTE 2 — VOTAÇÕES LIVRES (OPEN POLLS)
-- Separado de ClubBookPoll que fica exclusivo para escolha de livro.
-- ══════════════════════════════════════════════════════════════

-- ── 2a. Tabela de votações livres ─────────────────────────────
CREATE TABLE IF NOT EXISTS club_open_polls (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  created_by    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question      TEXT        NOT NULL CHECK (char_length(question) BETWEEN 3 AND 300),
  -- Opções como JSONB: [{"id":"opt_1","label":"Sábado às 15h"},{"id":"opt_2","label":"Domingo às 18h"}]
  options       JSONB       NOT NULL DEFAULT '[]',
  multi_select  BOOLEAN     NOT NULL DEFAULT FALSE,
  status        TEXT        NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'closed')),
  opens_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closes_at     TIMESTAMPTZ,                        -- NULL = encerramento manual
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_open_polls_club
  ON club_open_polls(club_id, status, created_at DESC);

ALTER TABLE club_open_polls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "open_polls: member select"
  ON club_open_polls FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Configurável: por padrão apenas manager cria; flag members_can_create_polls
-- pode relaxar isso no futuro sem mudar o schema.
CREATE POLICY "open_polls: manager insert"
  ON club_open_polls FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

CREATE POLICY "open_polls: creator or manager update"
  ON club_open_polls FOR UPDATE
  USING (auth.uid() = created_by OR is_club_manager(club_id, auth.uid()));

CREATE POLICY "open_polls: creator or manager delete"
  ON club_open_polls FOR DELETE
  USING (auth.uid() = created_by OR is_club_manager(club_id, auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE club_open_polls TO authenticated;

-- ── 2b. Votos nas votações livres ─────────────────────────────
CREATE TABLE IF NOT EXISTS club_open_poll_votes (
  poll_id    UUID        NOT NULL REFERENCES club_open_polls(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Array de option IDs selecionados (multi_select permite N itens)
  option_ids TEXT[]      NOT NULL DEFAULT '{}',
  voted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (poll_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_open_poll_votes_poll
  ON club_open_poll_votes(poll_id);

ALTER TABLE club_open_poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "open_poll_votes: member select"
  ON club_open_poll_votes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM club_open_polls op
      WHERE op.id = poll_id AND is_club_member(op.club_id, auth.uid())
    )
  );

-- Membro vota uma vez enquanto poll aberta
CREATE POLICY "open_poll_votes: self insert"
  ON club_open_poll_votes FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_open_polls op
      WHERE op.id = poll_id
        AND op.status = 'open'
        AND is_club_member(op.club_id, auth.uid())
    )
  );

-- Membro pode mudar o voto enquanto aberta
CREATE POLICY "open_poll_votes: self update"
  ON club_open_poll_votes FOR UPDATE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_open_polls op
      WHERE op.id = poll_id AND op.status = 'open'
    )
  );

GRANT SELECT, INSERT, UPDATE ON TABLE club_open_poll_votes TO authenticated;

-- ── 2c. RPC: resultados da votação livre ─────────────────────
CREATE OR REPLACE FUNCTION open_poll_results(p_poll_id UUID)
RETURNS TABLE (
  option_id       TEXT,
  option_label    TEXT,
  vote_count      BIGINT,
  pct             NUMERIC,
  voted_by_me     BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id    UUID;
  v_options    JSONB;
  v_total      BIGINT;
  v_my_votes   TEXT[];
BEGIN
  SELECT club_id, options
  INTO v_club_id, v_options
  FROM club_open_polls WHERE id = p_poll_id;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT COUNT(*) INTO v_total FROM club_open_poll_votes WHERE poll_id = p_poll_id;

  SELECT option_ids INTO v_my_votes
  FROM club_open_poll_votes
  WHERE poll_id = p_poll_id AND user_id = auth.uid();

  RETURN QUERY
  SELECT
    (opt->>'id')::TEXT                                        AS option_id,
    (opt->>'label')::TEXT                                     AS option_label,
    COUNT(v.user_id)                                          AS vote_count,
    CASE WHEN v_total > 0
         THEN ROUND(COUNT(v.user_id)::NUMERIC / v_total * 100, 1)
         ELSE 0 END                                           AS pct,
    (opt->>'id') = ANY(COALESCE(v_my_votes, '{}'))           AS voted_by_me
  FROM jsonb_array_elements(v_options) AS opt
  LEFT JOIN club_open_poll_votes v
    ON v.poll_id = p_poll_id
   AND (opt->>'id') = ANY(v.option_ids)
  GROUP BY opt->>'id', opt->>'label', opt
  ORDER BY vote_count DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION open_poll_results(UUID) TO authenticated;

-- ── 2d. Trigger: publica no feed ao abrir e fechar votação ───
CREATE OR REPLACE FUNCTION notify_open_poll_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Ao criar (abrir)
  IF TG_OP = 'INSERT' THEN
    INSERT INTO social_feed (user_id, event_type, club_id, book_title)
    VALUES (NEW.created_by, 'poll_opened', NEW.club_id, NEW.question);

    PERFORM notify_club_members(
      NEW.club_id, 'clubs', 'poll_opened',
      'Nova votação aberta!', NEW.question,
      '/clubs/' || NEW.club_id || '/polls',
      NEW.created_by
    );
  END IF;

  -- Ao fechar (status muda para 'closed')
  IF TG_OP = 'UPDATE' AND NEW.status = 'closed' AND OLD.status = 'open' THEN
    INSERT INTO social_feed (user_id, event_type, club_id, book_title)
    VALUES (NEW.created_by, 'poll_closed', NEW.club_id, NEW.question);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_open_poll_events ON club_open_polls;
CREATE TRIGGER trg_open_poll_events
  AFTER INSERT OR UPDATE OF status ON club_open_polls
  FOR EACH ROW EXECUTE FUNCTION notify_open_poll_event();
