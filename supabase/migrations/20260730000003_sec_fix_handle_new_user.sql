-- ============================================================
-- SEC-FIX P1-A: Sanitiza raw_user_meta_data em handle_new_user
--
-- Problema: O trigger de auto-criação de perfil inseria valores
-- diretamente de raw_user_meta_data (controlado por provedores
-- OAuth externos) sem validação de formato, tamanho ou charset.
-- Um provider malicioso poderia injetar usernames com caracteres
-- especiais, strings muito longas ou dados sensíveis.
--
-- Correção:
--   • name:     limpa com regexp, limita a 100 chars
--   • username: derivado do email (prefixo), apenas [a-z0-9_],
--               máx 30 chars, loop de unicidade com sufixo _N
--   • avatar_url: aceita apenas http(s) ou data:, descarta o resto
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_name       TEXT;
  v_username   TEXT;
  v_avatar_url TEXT;
  v_base       TEXT;
  v_counter    INT := 1;
BEGIN
  -- ── 1. Normaliza name ──────────────────────────────────────
  v_name := TRIM(COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'Usuário'
  ));
  -- Remove caracteres de controle e limita a 100 chars
  v_name := SUBSTR(
    REGEXP_REPLACE(v_name, '[\x00-\x1F\x7F]', '', 'g'),
    1, 100
  );
  -- Fallback se ficou vazio após sanitização
  IF TRIM(v_name) = '' THEN
    v_name := 'Usuário';
  END IF;

  -- ── 2. Deriva username seguro do prefixo do e-mail ─────────
  v_base := LOWER(SUBSTR(
    REGEXP_REPLACE(split_part(NEW.email, '@', 1), '[^a-z0-9]', '', 'g'),
    1, 25   -- reserva 5 chars para sufixo "_9999"
  ));
  -- Garante ao menos 3 chars no base
  IF LENGTH(v_base) < 3 THEN
    v_base := 'user_' || SUBSTR(REPLACE(NEW.id::text, '-', ''), 1, 8);
  END IF;

  v_username := v_base;
  -- Loop de unicidade: user → user_2 → user_3 …
  WHILE EXISTS (SELECT 1 FROM profiles WHERE username = v_username) LOOP
    v_username := v_base || '_' || v_counter;
    v_counter  := v_counter + 1;
  END LOOP;

  -- ── 3. Valida avatar_url (apenas http/https ou data:) ──────
  v_avatar_url := NEW.raw_user_meta_data->>'avatar_url';
  IF v_avatar_url IS NOT NULL AND v_avatar_url !~ '^https?://' AND v_avatar_url !~ '^data:' THEN
    v_avatar_url := NULL;  -- descarta URLs com esquemas inesperados
  END IF;

  -- ── 4. Insere perfil sanitizado ────────────────────────────
  INSERT INTO public.profiles (id, username, name, avatar_url, updated_at)
  VALUES (
    NEW.id,
    v_username,
    v_name,
    v_avatar_url,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Recria o trigger (a função foi substituída, mas o trigger ainda aponta
-- para ela corretamente; DROP + CREATE garante execução limpa)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
