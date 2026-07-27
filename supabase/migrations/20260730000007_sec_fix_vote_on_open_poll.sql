-- ============================================================
-- SEC-FIX P2-C: Valida option_ids em vote_on_open_poll()
--
-- Problema: A função aceitava qualquer array TEXT[] sem verificar:
--   a) se as opções existem dentro do JSONB options da poll
--   b) se multi_select=false foi violado (mais de 1 opção)
--   c) se o array está vazio (voto sem conteúdo)
--   d) se o tamanho do array é razoável (DoS potencial)
--
-- Correção: adiciona validações explícitas antes do INSERT/UPDATE
-- ============================================================

CREATE OR REPLACE FUNCTION vote_on_open_poll(p_poll_id UUID, p_option_ids TEXT[])
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club_id     UUID;
  v_options     JSONB;
  v_multi       BOOLEAN;
  v_valid_ids   TEXT[];
  v_invalid     TEXT[];
BEGIN
  -- Carrega poll e verifica status
  SELECT op.club_id, op.options, op.multi_select
  INTO   v_club_id, v_options, v_multi
  FROM   club_open_polls op
  WHERE  op.id = p_poll_id AND op.status = 'open';

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Votação não encontrada ou encerrada';
  END IF;

  IF NOT is_club_member(v_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Você não é membro deste clube';
  END IF;

  -- ── Validações de entrada ──────────────────────────────────

  -- Array não pode ser nulo ou vazio
  IF p_option_ids IS NULL OR ARRAY_LENGTH(p_option_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'É necessário selecionar ao menos uma opção';
  END IF;

  -- Limite de tamanho (proteção contra DoS)
  IF ARRAY_LENGTH(p_option_ids, 1) > 50 THEN
    RAISE EXCEPTION 'Número de opções excede o limite permitido';
  END IF;

  -- Respeita multi_select
  IF NOT v_multi AND ARRAY_LENGTH(p_option_ids, 1) > 1 THEN
    RAISE EXCEPTION 'Esta votação permite apenas uma opção';
  END IF;

  -- Extrai IDs válidos do JSONB da poll
  SELECT ARRAY_AGG(opt->>'id')
  INTO   v_valid_ids
  FROM   jsonb_array_elements(v_options) AS opt;

  -- Verifica se todos os IDs enviados existem na poll
  SELECT ARRAY_AGG(elem)
  INTO   v_invalid
  FROM   UNNEST(p_option_ids) AS elem
  WHERE  elem <> ALL(COALESCE(v_valid_ids, '{}'));

  IF v_invalid IS NOT NULL AND ARRAY_LENGTH(v_invalid, 1) > 0 THEN
    RAISE EXCEPTION 'Opções inválidas para esta votação: %',
      ARRAY_TO_STRING(v_invalid, ', ');
  END IF;

  -- ── Persiste voto ──────────────────────────────────────────
  INSERT INTO club_open_poll_votes (poll_id, user_id, option_ids)
  VALUES (p_poll_id, auth.uid(), p_option_ids)
  ON CONFLICT (poll_id, user_id) DO UPDATE
    SET option_ids = EXCLUDED.option_ids,
        voted_at   = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION vote_on_open_poll(UUID, TEXT[]) TO authenticated;
