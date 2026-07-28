/**
 * close-expired-polls
 *
 * Supabase Edge Function agendada via pg_cron (ou Supabase Scheduled Functions).
 * Fecha automaticamente as votações livres (club_open_polls) cujo closes_at
 * já foi atingido, publicando um evento no feed do clube para cada uma.
 *
 * Agenda sugerida: a cada 15 minutos.
 * No Supabase Dashboard → Edge Functions → Schedules, adicione:
 *   */15 * * * *   close-expired-polls
 *
 * Alternativamente, via pg_cron (se preferir tudo no banco):
 *   SELECT cron.schedule('close-expired-polls', '*/15 * * * *',
 *     $$ SELECT close_expired_polls() $$);
 *
 * A função SQL close_expired_polls() está na migration
 * 20260728000011_close_expired_polls_fn.sql e pode ser chamada diretamente
 * pelo pg_cron, tornando esta Edge Function opcional (útil apenas se quiser
 * lógica extra como push notification por encerramento de poll).
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (_req) => {
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // Chama a RPC que encerra as polls vencidas e retorna os registros afetados
  const { data: closed, error } = await supabase.rpc("close_expired_polls");

  if (error) {
    console.error("close_expired_polls error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const count = Array.isArray(closed) ? closed.length : 0;
  console.log(`close-expired-polls: ${count} poll(s) encerrada(s)`);

  return new Response(
    JSON.stringify({ closed: count, polls: closed }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
