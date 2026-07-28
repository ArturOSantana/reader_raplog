// Lumen Platform — Edge Function: cron-streak
// Spec §22 V1: Streak diário + desbloqueio de achievements
// Executar diariamente às 03:00 UTC via pg_cron ou Supabase Cron

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async () => {
  console.log({ level: 'info', service: 'cron-streak', event: 'start' })

  const today     = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  const todayStr     = today.toISOString().slice(0, 10)
  const yesterdayStr = yesterday.toISOString().slice(0, 10)

  // Busca todos os perfis ativos com streak > 0 ou que leram hoje
  const { data: activeUsers } = await supabase
    .from('profiles')
    .select('id, current_streak, longest_streak, last_read_at, xp_total')
    .eq('status', 'active')
    .limit(10000)

  if (!activeUsers?.length) {
    return new Response(JSON.stringify({ ok: true, processed: 0 }), {
      status: 200, headers: { 'Content-Type': 'application/json' },
    })
  }

  // IDs de usuários que tiveram sessão hoje
  const { data: todaySessions } = await supabase
    .from('reading_sessions')
    .select('user_id')
    .gte('started_at', `${todayStr}T00:00:00Z`)
    .lte('started_at', `${todayStr}T23:59:59Z`)

  const readTodaySet = new Set((todaySessions ?? []).map((s) => s.user_id))

  // IDs de usuários que leram ontem (para calcular continuidade)
  const { data: yesterdaySessions } = await supabase
    .from('reading_sessions')
    .select('user_id')
    .gte('started_at', `${yesterdayStr}T00:00:00Z`)
    .lte('started_at', `${yesterdayStr}T23:59:59Z`)

  const readYesterdaySet = new Set((yesterdaySessions ?? []).map((s) => s.user_id))

  let processed = 0
  const achievementsToGrant: Array<{ user_id: string; key: string }> = []

  for (const profile of activeUsers) {
    const readToday     = readTodaySet.has(profile.id)
    const readYesterday = readYesterdaySet.has(profile.id)

    let newStreak = profile.current_streak ?? 0

    if (readToday) {
      // Continuou o streak
      if (readYesterday || newStreak === 0) {
        newStreak = newStreak + 1
      }
      // Se não leu ontem mas leu hoje, recomeça do 1
      else if (!readYesterday && newStreak > 0) {
        newStreak = 1
      }
    } else {
      // Não leu hoje — zera streak se a última leitura foi antes de ontem
      const lastRead = profile.last_read_at ? new Date(profile.last_read_at).toISOString().slice(0, 10) : null
      if (lastRead && lastRead < yesterdayStr) {
        newStreak = 0
      }
    }

    const newLongest = Math.max(newStreak, profile.longest_streak ?? 0)

    // Só atualiza se mudou
    if (newStreak !== profile.current_streak || newLongest !== profile.longest_streak) {
      await supabase.from('profiles').update({
        current_streak: newStreak,
        longest_streak: newLongest,
        ...(readToday ? { last_read_at: new Date().toISOString() } : {}),
      }).eq('id', profile.id)

      processed++
    }

    // ── Verifica achievements de streak ──────────────────────────────────
    const streakMilestones = [
      { key: 'streak_3',   threshold: 3   },
      { key: 'streak_7',   threshold: 7   },
      { key: 'streak_30',  threshold: 30  },
      { key: 'streak_100', threshold: 100 },
      { key: 'streak_365', threshold: 365 },
    ]

    for (const { key, threshold } of streakMilestones) {
      if (newStreak >= threshold) {
        achievementsToGrant.push({ user_id: profile.id, key })
      }
    }
  }

  // ── Grant achievements (batch, ignore duplicados) ─────────────────────
  await grantAchievements(achievementsToGrant)

  // ── Verifica achievements de livros e páginas ─────────────────────────
  await checkBookAchievements()

  console.log({ level: 'info', service: 'cron-streak', processed })

  return new Response(JSON.stringify({ ok: true, processed }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

async function grantAchievements(toGrant: Array<{ user_id: string; key: string }>) {
  if (!toGrant.length) return

  // Busca IDs das achievements
  const keys = [...new Set(toGrant.map((a) => a.key))]
  const { data: achDefs } = await supabase
    .from('achievements')
    .select('id, key, xp_reward')
    .in('key', keys)

  if (!achDefs?.length) return

  const achMap = new Map(achDefs.map((a) => [a.key, a]))

  for (const { user_id, key } of toGrant) {
    const ach = achMap.get(key)
    if (!ach) continue

    const { error } = await supabase
      .from('user_achievements')
      .insert({ user_id, achievement_id: ach.id })
      .select()

    // Ignora erro de unique_violation (já desbloqueada)
    if (!error && ach.xp_reward > 0) {
      await supabase.rpc('increment_xp', { uid: user_id, amount: ach.xp_reward })
        .catch(() => {/* ignore se rpc não existir ainda */})
    }
  }
}

async function checkBookAchievements() {
  // Livros concluídos por usuário
  const { data: bookCounts } = await supabase
    .from('books')
    .select('user_id')
    .eq('status', 'finished')

  if (!bookCounts?.length) return

  const countMap: Record<string, number> = {}
  for (const { user_id } of bookCounts) {
    countMap[user_id] = (countMap[user_id] ?? 0) + 1
  }

  const bookMilestones = [
    { key: 'books_5',   threshold: 5   },
    { key: 'books_10',  threshold: 10  },
    { key: 'books_25',  threshold: 25  },
    { key: 'books_50',  threshold: 50  },
    { key: 'books_100', threshold: 100 },
  ]

  const toGrant: Array<{ user_id: string; key: string }> = []
  for (const [user_id, count] of Object.entries(countMap)) {
    for (const { key, threshold } of bookMilestones) {
      if (count >= threshold) {
        toGrant.push({ user_id, key })
      }
    }
  }

  await grantAchievements(toGrant)
}
