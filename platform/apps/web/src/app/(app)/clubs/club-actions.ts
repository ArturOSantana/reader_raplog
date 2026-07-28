'use server'

import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
import { createServerSupabase } from '@lumen/supabase/server'

/** Cria um novo clube */
export async function createClub(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const name       = (formData.get('name') as string)?.trim()
  const description = (formData.get('description') as string)?.trim() || null
  const category   = (formData.get('category') as string) || 'general'
  const visibility = (formData.get('visibility') as string) || 'public'

  if (!name || name.length < 3) return { error: 'Nome deve ter pelo menos 3 caracteres.' }
  if (name.length > 60) return { error: 'Nome muito longo.' }

  // Spec §16: conta nova < 7 dias — limite de 1 clube
  const { data: profile } = await supabase
    .from('profiles')
    .select('created_at')
    .eq('id', user.id)
    .single()

  const accountAgeDays = profile?.created_at
    ? (Date.now() - new Date(profile.created_at).getTime()) / 86400000
    : 999

  if (accountAgeDays < 7) {
    const { count } = await supabase
      .from('book_clubs')
      .select('*', { count: 'exact', head: true })
      .eq('owner_id', user.id)
    if ((count ?? 0) >= 1) {
      return { error: 'Contas novas podem criar apenas 1 clube. Aguarde 7 dias.' }
    }
  }

  // Gera slug a partir do nome
  const slug = name
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim().replace(/\s+/g, '-')
    + '-' + Math.random().toString(36).slice(2, 7)

  const { data: club, error } = await supabase
    .from('book_clubs')
    .insert({ owner_id: user.id, name, description, category, visibility, slug })
    .select('id, slug')
    .single()

  if (error) return { error: 'Não foi possível criar o clube. Tente novamente.' }

  // Insere o criador como owner
  await supabase.from('book_club_members').insert({
    club_id: club.id,
    user_id: user.id,
    role: 'owner',
  })

  await supabase.from('audit_logs').insert({
    actor_id: user.id,
    action: 'club.created',
    target_id: club.id,
    metadata: { name, visibility },
  })

  redirect(`/clubs/${club.slug}`)
}

/** Atualiza informações básicas do clube */
export async function updateClub(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const clubId     = formData.get('club_id') as string
  const name       = (formData.get('name') as string)?.trim()
  const description = (formData.get('description') as string)?.trim() || null
  const category   = formData.get('category') as string
  const visibility = formData.get('visibility') as string

  if (!name || name.length < 3) return { error: 'Nome deve ter pelo menos 3 caracteres.' }

  // Verifica ownership
  const { data: membership } = await supabase
    .from('book_club_members')
    .select('role')
    .eq('club_id', clubId)
    .eq('user_id', user.id)
    .single()

  if (!membership || !['owner', 'admin'].includes(membership.role)) {
    return { error: 'Sem permissão para editar este clube.' }
  }

  const { error } = await supabase
    .from('book_clubs')
    .update({ name, description, category, visibility })
    .eq('id', clubId)

  if (error) return { error: error.message }

  revalidatePath(`/clubs`)
  return { ok: true }
}

/** Define o livro atual do clube */
export async function setCurrentBook(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const clubId = formData.get('club_id') as string
  const title  = (formData.get('title') as string)?.trim()
  const author = (formData.get('author') as string)?.trim() || null
  const coverUrl = (formData.get('cover_url') as string)?.trim() || null

  if (!title) return { error: 'Título obrigatório.' }

  const { data: membership } = await supabase
    .from('book_club_members')
    .select('role')
    .eq('club_id', clubId)
    .eq('user_id', user.id)
    .single()

  if (!membership || !['owner', 'admin'].includes(membership.role)) {
    return { error: 'Sem permissão.' }
  }

  const { error } = await supabase
    .from('book_clubs')
    .update({
      current_book_title:     title,
      current_book_author:    author,
      current_book_cover_url: coverUrl,
    })
    .eq('id', clubId)

  if (error) return { error: error.message }

  revalidatePath(`/clubs`)
  return { ok: true }
}

/** Cria um check-in de leitura no clube */
export async function createCheckin(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const clubId    = formData.get('club_id') as string
  const pagesRead = parseInt(formData.get('pages_read') as string) || null
  const note      = (formData.get('note') as string)?.trim() || null

  const { error } = await supabase
    .from('book_club_checkins')
    .insert({ club_id: clubId, user_id: user.id, pages_read: pagesRead, note })

  if (error) return { error: error.message }

  revalidatePath(`/clubs/${clubId}`)
  return { ok: true }
}
