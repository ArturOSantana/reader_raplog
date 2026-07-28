// Lumen Platform — Edge Function: rate-limit
// Spec §8: Rate limiting aplicado na camada de Edge Functions / API Gateway
// Usa Redis (Upstash) via HTTP para contadores distribuídos

import { createClient } from 'jsr:@supabase/supabase-js@2'

const REDIS_URL    = Deno.env.get('UPSTASH_REDIS_REST_URL')!
const REDIS_TOKEN  = Deno.env.get('UPSTASH_REDIS_REST_TOKEN')!

// Spec §8: limites por ação
const LIMITS: Record<string, { max: number; windowSec: number }> = {
  login:          { max: 10,  windowSec: 60     },
  magic_link:     { max: 3,   windowSec: 3600   },
  review:         { max: 5,   windowSec: 60     },
  comment:        { max: 20,  windowSec: 60     },
  create_club:    { max: 2,   windowSec: 86400  },
  invite:         { max: 20,  windowSec: 3600   },
  follow:         { max: 50,  windowSec: 3600   },
  upload_image:   { max: 10,  windowSec: 3600   },
  api_public:     { max: 100, windowSec: 60     },
}

async function redisIncr(key: string, windowSec: number): Promise<number> {
  const res = await fetch(`${REDIS_URL}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${REDIS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify([
      ['INCR', key],
      ['EXPIRE', key, windowSec],
    ]),
  })
  const data = await res.json()
  return data[0]?.result ?? 0
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let body: { action: string; identifier: string } // identifier = IP ou user_id
  try {
    body = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const { action, identifier } = body
  const limit = LIMITS[action]

  if (!limit) {
    return new Response(JSON.stringify({ allowed: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const key = `rate:${action}:${identifier}`
  const count = await redisIncr(key, limit.windowSec)
  const allowed = count <= limit.max

  return new Response(JSON.stringify({
    allowed,
    count,
    max: limit.max,
    retry_after: allowed ? null : limit.windowSec,
  }), {
    status: allowed ? 200 : 429,
    headers: {
      'Content-Type': 'application/json',
      'X-RateLimit-Limit': String(limit.max),
      'X-RateLimit-Remaining': String(Math.max(0, limit.max - count)),
      'X-RateLimit-Reset': String(limit.windowSec),
    },
  })
})
