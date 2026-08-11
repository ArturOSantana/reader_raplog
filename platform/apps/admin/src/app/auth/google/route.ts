import { createClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const host = request.headers.get('host') ?? 'lumen-admin-ecru.vercel.app'
    const appUrl = (process.env.APP_URL ?? process.env.NEXT_PUBLIC_APP_URL ?? '').replace(/\/$/, '')
      || `https://${host}`

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

    if (!supabaseUrl || !supabaseAnonKey) {
      return NextResponse.redirect(
        `${appUrl}/login?error=missing_env&detail=${encodeURIComponent(!supabaseUrl ? 'SUPABASE_URL' : 'SUPABASE_ANON_KEY')}`,
      )
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey)

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${appUrl}/auth/callback`,
      },
    })

    if (error || !data.url) {
      return NextResponse.redirect(
        `${appUrl}/login?error=oauth_failed&detail=${encodeURIComponent(error?.message ?? 'no_url')}`,
      )
    }

    return NextResponse.redirect(data.url)
  } catch {
    const host = request.headers.get('host') ?? 'lumen-admin-ecru.vercel.app'
    const base = (process.env.APP_URL ?? process.env.NEXT_PUBLIC_APP_URL ?? '').replace(/\/$/, '')
      || `https://${host}`
    return NextResponse.redirect(`${base}/login?error=auth_exception`)
  }
}
