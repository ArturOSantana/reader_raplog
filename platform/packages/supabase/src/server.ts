import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

/**
 * Cliente para uso em Server Components, Route Handlers e Server Actions.
 * Lê cookies via next/headers para manter a sessão do usuário.
 *
 * TLS 1.3 é aplicado pelo Supabase automaticamente — nenhuma config adicional
 * necessária no cliente.
 */
export async function createServerSupabase() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  const cookieStore = await cookies()
  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          )
        } catch {
          // Server Components não podem setar cookies; ignorado.
        }
      },
    },
  })
}
