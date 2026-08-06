-- ============================================================
-- READLOG — Auto-desbloqueio de marcos de progresso
--
-- Bug: unlocked_at em club_milestones nunca era preenchido
-- automaticamente. O calendário e o milestone_discussion_screen
-- dependem desse campo para saber se o usuário "chegou" àquele
-- percentual do livro.
--
-- Solução: trigger em reading_sessions que, ao finalizar uma
-- sessão (status = 'finished'), calcula o progresso acumulado
-- do usuário no livro atual de cada clube e desbloqueia os
-- marcos correspondentes (25/50/75/100%).
--
-- O desbloqueio é coletivo (igual à política de tópicos): basta
-- QUALQUER membro do clube atingir o percentual para o marco
-- ser aberto para discussão. Isso mantém consistência com a
-- RLS policy existente em club_milestone_topics.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_auto_unlock_milestones()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club      RECORD;
  v_total     INTEGER;
  v_end_page  INTEGER;
  v_pct       NUMERIC;
BEGIN
  -- Só processa sessões que acabaram de ser finalizadas
  IF NEW.status <> 'finished' THEN
    RETURN NEW;
  END IF;
  -- Ignorar sessões sem página final registrada
  IF NEW.end_page IS NULL OR NEW.end_page <= 0 THEN
    RETURN NEW;
  END IF;

  -- Para cada clube cujo livro atual é o livro desta sessão
  -- e onde o usuário é membro, tenta desbloquear os marcos.
  FOR v_club IN
    SELECT bc.id AS club_id, bk.total_pages
    FROM book_clubs bc
    JOIN books bk ON bk.id = bc.current_book_id
    WHERE bc.current_book_id = NEW.book_id
      AND bk.total_pages > 0
      AND is_club_member(bc.id, NEW.user_id)
  LOOP
    v_total := v_club.total_pages;

    -- Página máxima atingida pelo usuário neste livro/clube
    SELECT COALESCE(MAX(rs.end_page), 0)
    INTO v_end_page
    FROM reading_sessions rs
    WHERE rs.user_id = NEW.user_id
      AND rs.book_id = NEW.book_id
      AND rs.status  = 'finished';

    v_pct := (v_end_page::NUMERIC / v_total) * 100;

    -- Desbloqueia todos os marcos cujo percentual foi atingido
    -- e que ainda não têm unlocked_at preenchido.
    UPDATE club_milestones
    SET unlocked_at = NOW()
    WHERE club_id       = v_club.club_id
      AND unlocked_at   IS NULL
      AND milestone_pct <= v_pct;

  END LOOP;

  RETURN NEW;
END;
$$;

-- Remove versão anterior caso exista
DROP TRIGGER IF EXISTS trg_auto_unlock_milestones ON reading_sessions;

CREATE TRIGGER trg_auto_unlock_milestones
  AFTER INSERT OR UPDATE OF status ON reading_sessions
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_unlock_milestones();

-- Backfill: desbloqueia marcos que já deveriam estar abertos
-- com base em sessões históricas existentes.
DO $$
DECLARE
  v_club   RECORD;
  v_pct    NUMERIC;
  v_total  INTEGER;
BEGIN
  FOR v_club IN
    SELECT DISTINCT cm.club_id, bc.current_book_id, bk.total_pages
    FROM club_milestones cm
    JOIN book_clubs bc ON bc.id = cm.club_id
    JOIN books bk ON bk.id = bc.current_book_id
    WHERE cm.unlocked_at IS NULL
      AND bk.total_pages > 0
  LOOP
    -- Maior página atingida por qualquer membro do clube neste livro
    SELECT COALESCE(MAX(rs.end_page), 0)
    INTO v_pct
    FROM reading_sessions rs
    JOIN book_club_members bcm
      ON bcm.user_id = rs.user_id
     AND bcm.club_id = v_club.club_id
    WHERE rs.book_id = v_club.current_book_id
      AND rs.status  = 'finished';

    v_pct := (v_pct::NUMERIC / v_club.total_pages) * 100;

    UPDATE club_milestones
    SET unlocked_at = NOW()
    WHERE club_id       = v_club.club_id
      AND unlocked_at   IS NULL
      AND milestone_pct <= v_pct;
  END LOOP;
END $$;
