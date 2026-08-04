-- ============================================================
-- RPC: insert_feed_event
--
-- Problema: A migração 20260730000005_sec_fix_restrict_grants
-- revogou INSERT/UPDATE/DELETE direto na tabela social_feed do
-- role authenticated. O app mobile ainda tentava inserir
-- diretamente, causando "permission denied for table social_feed".
--
-- Solução: Função SECURITY DEFINER que valida o chamador e
-- insere no feed. O cliente chama via rpc('insert_feed_event').
-- ============================================================

CREATE OR REPLACE FUNCTION insert_feed_event(
  p_event_type          TEXT,
  p_book_title          TEXT    DEFAULT NULL,
  p_book_author         TEXT    DEFAULT NULL,
  p_rating              INT     DEFAULT NULL,
  p_review              TEXT    DEFAULT NULL,
  p_reading_time_minutes INT    DEFAULT NULL,
  p_pages_read          INT     DEFAULT NULL,
  p_current_page        INT     DEFAULT NULL,
  p_session_minutes     INT     DEFAULT NULL,
  p_streak_days         INT     DEFAULT NULL,
  p_achievement_name    TEXT    DEFAULT NULL,
  p_goal_description    TEXT    DEFAULT NULL,
  p_club_id             UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_new_id  UUID;
  v_allowed_types TEXT[] := ARRAY[
    'finished_book', 'started_book', 'streak',
    'achievement', 'goal_completed', 'reading_session'
  ];
BEGIN
  v_user_id := auth.uid();

  -- Usuário deve estar autenticado
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Usuário deve estar ativo
  IF NOT is_active_user() THEN
    RAISE EXCEPTION 'Conta suspensa ou inativa';
  END IF;

  -- Valida o tipo de evento (allowlist)
  IF p_event_type IS NULL OR NOT (p_event_type = ANY(v_allowed_types)) THEN
    RAISE EXCEPTION 'Tipo de evento inválido: %', p_event_type;
  END IF;

  -- Valida rating (1–5 quando informado)
  IF p_rating IS NOT NULL AND p_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'Avaliação deve ser entre 1 e 5';
  END IF;

  -- club_id obrigatório para reading_session
  IF p_event_type = 'reading_session' AND p_club_id IS NULL THEN
    RAISE EXCEPTION 'club_id é obrigatório para eventos do tipo reading_session';
  END IF;

  INSERT INTO social_feed (
    user_id,
    event_type,
    book_title,
    book_author,
    rating,
    review,
    reading_time_minutes,
    pages_read,
    current_page,
    session_minutes,
    streak_days,
    achievement_name,
    goal_description,
    club_id
  ) VALUES (
    v_user_id,
    p_event_type,
    p_book_title,
    p_book_author,
    p_rating,
    p_review,
    p_reading_time_minutes,
    p_pages_read,
    p_current_page,
    p_session_minutes,
    p_streak_days,
    p_achievement_name,
    p_goal_description,
    p_club_id
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION insert_feed_event(
  TEXT, TEXT, TEXT, INT, TEXT, INT, INT, INT, INT, INT, TEXT, TEXT, UUID
) TO authenticated;
