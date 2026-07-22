-- ============================================================
-- READLOG — Clube do Livro v2
-- Adiciona: status, papéis owner/admin/member, convite,
--           visibilidade, histórico de livros e lógica de
--           transferência automática de dono.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Alterações em book_clubs
-- ────────────────────────────────────────────────────────────

ALTER TABLE book_clubs
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'on_vacation', 'closed')),
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('public', 'private')),
  ADD COLUMN IF NOT EXISTS invite_code TEXT,
  ADD COLUMN IF NOT EXISTS max_admins INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS admins_can_promote BOOLEAN NOT NULL DEFAULT FALSE;

-- invite_code único (gerado na criação via trigger abaixo)
CREATE UNIQUE INDEX IF NOT EXISTS idx_book_clubs_invite_code
  ON book_clubs(invite_code)
  WHERE invite_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_book_clubs_status ON book_clubs(status);

-- Backfill invite_code para clubes existentes
UPDATE book_clubs
SET invite_code = upper(
  substring(translate(gen_random_uuid()::text, '-', ''), 1, 4) || '-' ||
  substring(translate(gen_random_uuid()::text, '-', ''), 1, 4)
)
WHERE invite_code IS NULL;

-- ────────────────────────────────────────────────────────────
-- 2. Alterações em book_club_members — novos papéis
-- ────────────────────────────────────────────────────────────

-- Remove constraint antiga de role
ALTER TABLE book_club_members
  DROP CONSTRAINT IF EXISTS book_club_members_role_check;

-- Adiciona nova constraint: owner | admin | member
ALTER TABLE book_club_members
  ADD CONSTRAINT book_club_members_role_check
  CHECK (role IN ('owner', 'admin', 'member'));

-- Migra todos os antigos 'admin' e 'moderator' para os novos papéis.
-- A lógica: o admin_id do clube torna-se 'owner'; demais 'admin'/'moderator'
-- tornam-se 'admin'; membros ficam como estão.
UPDATE book_club_members bcm
SET role = 'owner'
WHERE bcm.role = 'admin'
  AND bcm.user_id = (
    SELECT admin_id FROM book_clubs WHERE id = bcm.club_id
  );

UPDATE book_club_members
SET role = 'admin'
WHERE role IN ('admin', 'moderator')
  AND (club_id, user_id) NOT IN (
    SELECT club_id, user_id FROM book_club_members WHERE role = 'owner'
  );

-- ────────────────────────────────────────────────────────────
-- 3. Tabela de histórico de livros do clube
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_book_history (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id             UUID NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  book_id             UUID REFERENCES books(id) ON DELETE SET NULL,
  book_title          TEXT NOT NULL,
  book_author         TEXT,
  started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at            TIMESTAMPTZ,
  meeting_count       INT NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_club_book_history_club
  ON club_book_history(club_id);

CREATE INDEX IF NOT EXISTS idx_club_book_history_started
  ON club_book_history(started_at DESC);

ALTER TABLE club_book_history ENABLE ROW LEVEL SECURITY;

-- Membros do clube podem ver o histórico
CREATE POLICY "club_book_history: member select"
  ON club_book_history FOR SELECT
  USING (is_club_member(club_id, auth.uid()));

-- Dono e admins podem inserir
CREATE POLICY "club_book_history: manager insert"
  ON club_book_history FOR INSERT
  WITH CHECK (is_club_manager(club_id, auth.uid()));

-- Dono e admins podem atualizar
CREATE POLICY "club_book_history: manager update"
  ON club_book_history FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

-- ────────────────────────────────────────────────────────────
-- 4. Funções auxiliares SECURITY DEFINER (novos papéis)
-- ────────────────────────────────────────────────────────────

-- is_club_member: qualquer participante (owner, admin, member)
CREATE OR REPLACE FUNCTION is_club_member(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id AND user_id = p_user_id
  );
$$;

-- is_club_owner: somente dono
CREATE OR REPLACE FUNCTION is_club_owner(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role = 'owner'
  );
$$;

-- is_club_manager: dono ou admin (pode gerenciar clube)
CREATE OR REPLACE FUNCTION is_club_manager(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id = p_user_id
      AND role IN ('owner', 'admin')
  );
$$;

-- Compatibilidade retroativa: is_club_moderator e is_club_admin
-- passam a usar a mesma lógica de is_club_manager
CREATE OR REPLACE FUNCTION is_club_moderator(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_club_manager(p_club_id, p_user_id);
$$;

CREATE OR REPLACE FUNCTION is_club_admin(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_club_manager(p_club_id, p_user_id);
$$;

-- ────────────────────────────────────────────────────────────
-- 5. RLS em book_clubs — atualiza políticas de UPDATE/DELETE
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "book_clubs: admin update" ON book_clubs;
DROP POLICY IF EXISTS "book_clubs: admin delete" ON book_clubs;

-- Dono ou admin podem editar o clube (exceto excluir)
CREATE POLICY "book_clubs: manager update"
  ON book_clubs FOR UPDATE
  USING (is_club_manager(id, auth.uid()));

-- Somente dono pode deletar, e apenas se encerrado há 30+ dias
CREATE POLICY "book_clubs: owner delete"
  ON book_clubs FOR DELETE
  USING (
    is_club_owner(id, auth.uid())
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at <= NOW() - INTERVAL '30 days'
  );

-- ────────────────────────────────────────────────────────────
-- 6. RLS em book_club_members — atualiza políticas
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "club_members: moderator update"  ON book_club_members;
DROP POLICY IF EXISTS "club_members: self or admin delete" ON book_club_members;

-- Dono ou admin podem alterar papéis de membros
CREATE POLICY "club_members: manager update"
  ON book_club_members FOR UPDATE
  USING (is_club_manager(club_id, auth.uid()));

-- Membro pode sair; manager pode remover qualquer um (exceto owner)
CREATE POLICY "club_members: self or manager delete"
  ON book_club_members FOR DELETE
  USING (
    auth.uid() = user_id
    OR (
      is_club_manager(club_id, auth.uid())
      AND role != 'owner'
    )
  );

-- ────────────────────────────────────────────────────────────
-- 7. Trigger: gera invite_code único ao criar clube
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_club_invite_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  IF NEW.invite_code IS NOT NULL THEN
    RETURN NEW;
  END IF;
  LOOP
    v_code := upper(
      substring(translate(gen_random_uuid()::text, '-', ''), 1, 4) || '-' ||
      substring(translate(gen_random_uuid()::text, '-', ''), 1, 4)
    );
    SELECT EXISTS (
      SELECT 1 FROM book_clubs WHERE invite_code = v_code
    ) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;
  NEW.invite_code := v_code;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_club_invite_code ON book_clubs;
CREATE TRIGGER trg_club_invite_code
  BEFORE INSERT ON book_clubs
  FOR EACH ROW EXECUTE FUNCTION generate_club_invite_code();

-- ────────────────────────────────────────────────────────────
-- 8. Função RPC: transferência de dono ao sair
--    Executa atomicamente: promove próximo admin/membro ou
--    encerra o clube se ficar vazio.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION leave_club_as_owner(p_club_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller   UUID := auth.uid();
  v_next_id  UUID;
  v_result   TEXT;
BEGIN
  -- Verifica que o caller é o dono
  IF NOT is_club_owner(p_club_id, v_caller) THEN
    RAISE EXCEPTION 'Apenas o dono pode usar esta função';
  END IF;

  -- Procura próximo admin mais antigo
  SELECT user_id INTO v_next_id
  FROM book_club_members
  WHERE club_id = p_club_id
    AND user_id != v_caller
    AND role = 'admin'
  ORDER BY joined_at ASC
  LIMIT 1;

  -- Se não há admin, procura membro mais antigo
  IF v_next_id IS NULL THEN
    SELECT user_id INTO v_next_id
    FROM book_club_members
    WHERE club_id = p_club_id
      AND user_id != v_caller
      AND role = 'member'
    ORDER BY joined_at ASC
    LIMIT 1;
  END IF;

  IF v_next_id IS NOT NULL THEN
    -- Promove o próximo como owner
    UPDATE book_club_members
    SET role = 'owner'
    WHERE club_id = p_club_id AND user_id = v_next_id;
    -- Remove o dono atual
    DELETE FROM book_club_members
    WHERE club_id = p_club_id AND user_id = v_caller;
    v_result := 'transferred';
  ELSE
    -- Ninguém mais: encerra o clube automaticamente
    DELETE FROM book_club_members
    WHERE club_id = p_club_id AND user_id = v_caller;
    UPDATE book_clubs
    SET status = 'closed', closed_at = NOW()
    WHERE id = p_club_id;
    v_result := 'closed';
  END IF;

  RETURN v_result;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 9. Atualiza view book_clubs_with_count para incluir status
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW book_clubs_with_count AS
  SELECT bc.*,
         COUNT(m.id) AS member_count
  FROM book_clubs bc
  LEFT JOIN book_club_members m ON m.club_id = bc.id
  GROUP BY bc.id;
