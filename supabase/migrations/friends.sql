-- ============================================================
-- READLOG -- Friends & Friend Requests
-- Execute no SQL Editor do Supabase Dashboard
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Politica extra em profiles: qualquer usuario autenticado
-- pode ler o perfil de outro (para busca de amigos).
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles: authenticated read" ON profiles;
CREATE POLICY "profiles: authenticated read"
  ON profiles FOR SELECT
  USING (auth.role() = 'authenticated');

-- ────────────────────────────────────────────────────────────
-- friend_requests
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friend_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_sender   ON friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON friend_requests(receiver_id);

CREATE OR REPLACE FUNCTION update_updated_at_friend_requests()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_friend_requests_updated_at
  BEFORE UPDATE ON friend_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_friend_requests();

ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

-- Quem enviou ou recebeu pode ler
CREATE POLICY "friend_requests: participant select"
  ON friend_requests FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Apenas o remetente insere (nao pode enviar para si mesmo)
CREATE POLICY "friend_requests: sender insert"
  ON friend_requests FOR INSERT
  WITH CHECK (auth.uid() = sender_id AND sender_id <> receiver_id);

-- Apenas o receptor pode aceitar/rejeitar; remetente pode cancelar
CREATE POLICY "friend_requests: participant update"
  ON friend_requests FOR UPDATE
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Participantes podem excluir (cancelar / remover)
CREATE POLICY "friend_requests: participant delete"
  ON friend_requests FOR DELETE
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ────────────────────────────────────────────────────────────
-- friends  (tabela de amizades confirmadas -- bidirecional)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friends (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friends_user_id   ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_id ON friends(friend_id);

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

CREATE POLICY "friends: owner select"
  ON friends FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "friends: owner insert"
  ON friends FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "friends: owner delete"
  ON friends FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- FUNCTION: accept_friend_request(p_request_id uuid)
-- Aceita a solicitacao e insere as duas linhas em friends.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION accept_friend_request(p_request_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_sender   UUID;
  v_receiver UUID;
BEGIN
  SELECT sender_id, receiver_id
    INTO v_sender, v_receiver
    FROM friend_requests
   WHERE id = p_request_id
     AND receiver_id = auth.uid()
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitacao nao encontrada ou sem permissao';
  END IF;

  UPDATE friend_requests
     SET status = 'accepted'
   WHERE id = p_request_id;

  INSERT INTO friends (user_id, friend_id)
  VALUES (v_sender,   v_receiver),
         (v_receiver, v_sender)
  ON CONFLICT DO NOTHING;
END;
$$;
