import { createServerSupabase } from '@lumen/supabase/server'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const { origin } = new URL(request.url)
  const appUrl = process.env.NEXT_PUBLIC_APP_URL?.replace(/\/$/, '') ?? origin
  const supabase = await createServerSupabase()

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${appUrl}/auth/callback`,
    },
  })

  if (error || !data.url) {
    return NextResponse.redirect(`${appUrl}/login?error=oauth_failed`)
  }

  return NextResponse.redirect(data.url)
}
