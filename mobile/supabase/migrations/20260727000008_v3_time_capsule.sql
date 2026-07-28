-- ============================================================
-- READLOG V3 — Cápsula do Tempo
-- ============================================================
-- Membros depositam uma mensagem que só será revelada após
-- um período configurado (padrão: 1 ano).
-- A entrega é feita via push + notificação in-app, disparada
-- por uma Supabase Edge Function agendada com pg_cron.
-- ============================================================

-- ── 1. Tabela club_time_capsule ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_time_capsule (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID        NOT NULL REFERENCES book_clubs(id) ON DELETE CASCADE,
  author_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Conteúdo da mensagem (só revelado após reveal_at)
  message       TEXT        NOT NULL CHECK (char_length(message) BETWEEN 1 AND 1000),
  -- Contexto opcional (livro que estava lendo ao escrever)
  book_id       UUID        REFERENCES books(id) ON DELETE SET NULL,
  book_title    TEXT,
  -- Controle de revelação
  reveal_at     TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 year'),
  is_revealed   BOOLEAN     NOT NULL DEFAULT FALSE,
  revealed_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_capsule_club
  ON club_time_capsule(club_id, reveal_at ASC);

CREATE INDEX IF NOT EXISTS idx_time_capsule_pending
  ON club_time_capsule(reveal_at)
  WHERE is_revealed = FALSE;

ALTER TABLE club_time_capsule ENABLE ROW LEVEL SECURITY;

-- Política: membros veem apenas mensagens já reveladas ou as próprias (antes da revelação)
CREATE POLICY "capsule: select revealed or own"
  ON club_time_capsule FOR SELECT
  USING (
    is_club_member(club_id, auth.uid())
    AND (
      is_revealed = TRUE
      OR author_id = auth.uid()
    )
  );

-- Qualquer membro pode depositar uma mensagem
CREATE POLICY "capsule: member insert"
  ON club_time_capsule FOR INSERT
  WITH CHECK (
    auth.uid() = author_id
    AND is_club_member(club_id, auth.uid())
    AND reveal_at > NOW()
  );

-- Autor pode deletar antes de ser revelado
CREATE POLICY "capsule: author delete unrevealed"
  ON club_time_capsule FOR DELETE
  USING (
    auth.uid() = author_id
    AND is_revealed = FALSE
  );

GRANT SELECT, INSERT, DELETE ON TABLE club_time_capsule TO authenticated;

-- ── 2. Função de revelação (chamada pela Edge Function agendada) ─────────────
-- Marca como revelada e envia notificação in-app para o clube.
-- A Edge Function faz: SELECT reveal_due_capsules() → notifica via push.

CREATE OR REPLACE FUNCTION reveal_due_capsules()
RETURNS TABLE(
  capsule_id  UUID,
  club_id     UUID,
  author_id   UUID,
  author_name TEXT,
  message     TEXT,
  book_title  TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Atualiza as cápsulas vencidas
  UPDATE club_time_capsule
  SET is_revealed = TRUE,
      revealed_at = NOW()
  WHERE is_revealed = FALSE
    AND reveal_at <= NOW();

  -- Retorna as recém-reveladas para a Edge Function enviar notificação
  RETURN QUERY
    SELECT
      tc.id,
      tc.club_id,
      tc.author_id,
      p.name,
      tc.message,
      tc.book_title
    FROM club_time_capsule tc
    LEFT JOIN profiles p ON p.id = tc.author_id
    WHERE tc.is_revealed = TRUE
      AND tc.revealed_at >= NOW() - INTERVAL '5 minutes'
    ORDER BY tc.revealed_at;
END;
$$;

-- Apenas service_role chama esta função (via Edge Function agendada)
REVOKE EXECUTE ON FUNCTION reveal_due_capsules() FROM authenticated;
GRANT  EXECUTE ON FUNCTION reveal_due_capsules() TO service_role;
