-- ============================================================
-- READLOG — Corrige upsert em club_bet_participants e
--           club_open_poll_votes (ambos faltavam WITH CHECK
--           na policy UPDATE, causando rejeição silenciosa
--           do PostgREST ao tentar sobrescrever voto/aposta).
-- ============================================================

-- ── 1. Apostas — corrige policy UPDATE ───────────────────────
DROP POLICY IF EXISTS "bet_participants: self update" ON club_bet_participants;

CREATE POLICY "bet_participants: self update"
  ON club_bet_participants FOR UPDATE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id AND cb.status = 'open'
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_bets cb
      WHERE cb.id = bet_id AND cb.status = 'open'
    )
  );

-- ── 2. Votações livres — corrige policy UPDATE ────────────────
DROP POLICY IF EXISTS "open_poll_votes: self update" ON club_open_poll_votes;

CREATE POLICY "open_poll_votes: self update"
  ON club_open_poll_votes FOR UPDATE
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_open_polls op
      WHERE op.id = poll_id AND op.status = 'open'
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM club_open_polls op
      WHERE op.id = poll_id AND op.status = 'open'
    )
  );

-- ── 3. RPC join_bet — SECURITY DEFINER, atomicamente segura ──
-- Substitui o upsert direto do Dart, que dependia de ambas as
-- policies (INSERT + UPDATE) passarem simultaneamente.
CREATE OR REPLACE FUNCTION join_bet(p_bet_id UUID, p_side TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  SELECT cb.club_id INTO v_club_id
  FROM club_bets cb
  WHERE cb.id = p_bet_id AND cb.status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Aposta não encontrada ou já encerrada';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Você não é membro deste clube';
  END IF;

  IF p_side NOT IN ('a', 'b') THEN
    RAISE EXCEPTION 'side deve ser ''a'' ou ''b''';
  END IF;

  INSERT INTO club_bet_participants (bet_id, user_id, side)
  VALUES (p_bet_id, auth.uid(), p_side)
  ON CONFLICT (bet_id, user_id) DO UPDATE
    SET side = EXCLUDED.side;
END;
$$;

GRANT EXECUTE ON FUNCTION join_bet(UUID, TEXT) TO authenticated;

-- ── 4. RPC vote_on_open_poll — SECURITY DEFINER ───────────────
CREATE OR REPLACE FUNCTION vote_on_open_poll(p_poll_id UUID, p_option_ids TEXT[])
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id UUID;
BEGIN
  SELECT op.club_id INTO v_club_id
  FROM club_open_polls op
  WHERE op.id = p_poll_id AND op.status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Votação não encontrada ou encerrada';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Você não é membro deste clube';
  END IF;

  INSERT INTO club_open_poll_votes (poll_id, user_id, option_ids)
  VALUES (p_poll_id, auth.uid(), p_option_ids)
  ON CONFLICT (poll_id, user_id) DO UPDATE
    SET option_ids = EXCLUDED.option_ids,
        voted_at   = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION vote_on_open_poll(UUID, TEXT[]) TO authenticated;
