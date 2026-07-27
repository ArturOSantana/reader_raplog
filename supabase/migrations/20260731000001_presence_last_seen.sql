-- ============================================================
-- READLOG — Presença em Tempo Real (last_seen_at)
-- Adiciona o campo last_seen_at ao profiles e uma RPC para
-- atualizar a presença do usuário ao iniciar/continuar sessão.
-- Utilizado para exibir "X está lendo agora · há Y min".
-- ============================================================

-- ── 1. Coluna last_seen_at no perfil ─────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- ── 2. Índice para consultas de presença recente ─────────────
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen
  ON profiles(last_seen_at DESC)
  WHERE last_seen_at IS NOT NULL;

-- ── 3. RPC: atualizar presença do usuário ─────────────────────
-- Chamada pelo app ao iniciar sessão de leitura ou em intervalos
-- regulares enquanto o timer de sessão está ativo.
-- Retorna o timestamp gravado.
CREATE OR REPLACE FUNCTION update_my_presence()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
BEGIN
  UPDATE profiles
  SET last_seen_at = v_now
  WHERE id = auth.uid();

  RETURN v_now;
END;
$$;

GRANT EXECUTE ON FUNCTION update_my_presence() TO authenticated;

-- ── 4. RPC: presença de membros do clube ──────────────────────
-- Retorna membros que estiveram ativos nos últimos N minutos.
-- Padrão: 30 minutos — "está lendo agora" se < 5 min,
--         "leu recentemente" se < 30 min.
CREATE OR REPLACE FUNCTION club_presence(
  p_club_id        UUID,
  p_window_minutes INTEGER DEFAULT 30
)
RETURNS TABLE (
  user_id      UUID,
  user_name    TEXT,
  avatar_url   TEXT,
  last_seen_at TIMESTAMPTZ,
  minutes_ago  INTEGER,
  is_active    BOOLEAN   -- TRUE se < 5 min (considerado "online")
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_club_member(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.name,
    p.avatar_url,
    p.last_seen_at,
    EXTRACT(EPOCH FROM (NOW() - p.last_seen_at))::INTEGER / 60 AS minutes_ago,
    p.last_seen_at >= NOW() - INTERVAL '5 minutes'             AS is_active
  FROM book_club_members bcm
  JOIN profiles p ON p.id = bcm.user_id
  WHERE bcm.club_id = p_club_id
    AND p.last_seen_at IS NOT NULL
    AND p.last_seen_at >= NOW() - (p_window_minutes || ' minutes')::INTERVAL
    AND p.id != auth.uid()   -- não mostra o próprio usuário
  ORDER BY p.last_seen_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION club_presence(UUID, INTEGER) TO authenticated;
