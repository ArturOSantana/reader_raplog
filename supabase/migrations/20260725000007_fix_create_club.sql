-- ============================================================
-- READLOG — Fix: criação de clube falhando
--
-- Garante de forma idempotente que:
-- 1. A constraint de role em book_club_members aceita 'owner'
-- 2. O trigger de invite_code existe em book_clubs
-- 3. O trigger de geração de invite_code está correto
-- ============================================================

-- ── 1. Corrige constraint de role em book_club_members ───────
-- A migration 010 pode não ter alterado a constraint corretamente.
-- Remove qualquer constraint de role existente e recria nomeada.

ALTER TABLE book_club_members
  DROP CONSTRAINT IF EXISTS book_club_members_role_check;

ALTER TABLE book_club_members
  ADD CONSTRAINT book_club_members_role_check
  CHECK (role IN ('owner', 'admin', 'member'));

-- ── 2. Garante função e trigger de invite_code ────────────────

CREATE OR REPLACE FUNCTION generate_club_invite_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_code  TEXT;
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
