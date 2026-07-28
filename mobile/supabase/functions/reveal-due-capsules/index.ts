/**
 * reveal-due-capsules
 *
 * Supabase Edge Function agendada via pg_cron (ou Supabase Scheduled Functions).
 * Revela cápsulas do tempo (club_time_capsule) cujo reveal_at já foi atingido,
 * gerando notificação in-app para todos os membros do clube.
 *
 * Agenda sugerida: uma vez por dia (ou mais frequente se quiser horário exato).
 * No Supabase Dashboard → Edge Functions → Schedules, adicione:
 *   0 9 * * *   reveal-due-capsules   (toda manhã às 9h UTC)
 *
 * A função SQL reveal_due_capsules() (migration 20260727000008) é chamada com
 * service_role e retorna os registros recém-revelados. Para cada um, esta
 * função gera uma notificação in-app via notify_club_members (se disponível)
 * e pode enviar push via FCM/APNS quando integrado.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (_req) => {
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // Revela cápsulas vencidas e retorna as recém-reveladas
  const { data: revealed, error } = await supabase.rpc("reveal_due_capsules");

  if (error) {
    console.error("reveal_due_capsules error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const capsules = Array.isArray(revealed) ? revealed : [];
  console.log(`reveal-due-capsules: ${capsules.length} cápsula(s) revelada(s)`);

  // Para cada cápsula revelada, gera notificação in-app via service_role
  for (const capsule of capsules) {
    const preview = capsule.message?.substring(0, 80) ?? "";
    const authorLabel = capsule.author_name ?? "Um membro";
    const bookHint = capsule.book_title ? ` sobre "${capsule.book_title}"` : "";

    // Insere notificação in-app diretamente para todos os membros do clube
    // usando o padrão da tabela notification_items (migration 20260722000021)
    const { error: notifError } = await supabase
      .from("notification_items")
      .insert({
        club_id: capsule.club_id,
        event_type: "capsule_revealed",
        title: "📬 Cápsula do Tempo revelada!",
        body: `${authorLabel} deixou uma mensagem${bookHint}: "${preview}${preview.length >= 80 ? "…" : ""}"`,
        action_url: `/clubs/${capsule.club_id}/capsule`,
        // user_id NULL = notificação de clube (broadcast para membros)
        user_id: null,
      });

    if (notifError) {
      // Não aborta — continua revelando as demais mesmo se notificação falhar
      console.warn(
        `Notificação falhou para cápsula ${capsule.capsule_id}:`,
        notifError.message,
      );
    }
  }

  return new Response(
    JSON.stringify({ revealed: capsules.length, capsules }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
