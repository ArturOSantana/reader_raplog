-- ============================================================
-- SEC-FIX P2-A: Restringe grants ao role "authenticated"
--
-- Problema: Todas as tabelas tinham SELECT+INSERT+UPDATE+DELETE
-- concedidos ao role authenticated de forma indiscriminada.
-- Isso significa que qualquer tabela criada sem RLS ficaria
-- completamente exposta a todos os usuários autenticados.
--
-- Correção:
--   • Revoga grants amplos das tabelas onde o usuário não deve
--     gravar diretamente (RLS já controla isso via funções RPC)
--   • social_feed e book_clubs: apenas SELECT — escrita ocorre
--     exclusivamente via funções SECURITY DEFINER
--   • profiles: apenas SELECT+UPDATE (sem INSERT ou DELETE
--     direto — criação é feita pelo trigger handle_new_user)
--   • Demais tabelas mantêm apenas os grants necessários
-- ============================================================

-- ── profiles: usuário lê e atualiza o próprio perfil via RLS;
--              não faz INSERT (trigger) nem DELETE (operação de conta)
REVOKE INSERT, DELETE ON TABLE profiles FROM authenticated;

-- ── social_feed: escrita exclusivamente via funções RPC
--                (insert_session_to_feed, notify_open_poll_event, etc.)
REVOKE INSERT, UPDATE, DELETE ON TABLE social_feed FROM authenticated;

-- ── book_clubs: criação e exclusão via RPC (create_club, etc.)
--               UPDATE permitido para managers via RLS
REVOKE INSERT, DELETE ON TABLE book_clubs FROM authenticated;

-- ── Tabelas que nunca devem receber DELETE direto do cliente ─
REVOKE DELETE ON TABLE book_club_meetings FROM authenticated;
REVOKE DELETE ON TABLE meeting_rsvps       FROM authenticated;

-- ── Comentário de auditoria ──────────────────────────────────
-- Para verificar grants ativos em produção:
--   SELECT grantee, table_name, privilege_type
--   FROM   information_schema.role_table_grants
--   WHERE  grantee = 'authenticated'
--   ORDER  BY table_name, privilege_type;
--
-- Para verificar tabelas SEM RLS (deve retornar 0 linhas):
--   SELECT tablename FROM pg_tables
--   WHERE  schemaname = 'public' AND NOT rowsecurity;
