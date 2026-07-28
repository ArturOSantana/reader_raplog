'use server'

import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
import { createServerSupabase } from '@lumen/supabase/server'

/** Atualiza status de múltiplos livros de uma vez */
export async function batchUpdateStatus(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const idsRaw = formData.get('ids') as string
  const status = formData.get('status') as string

  if (!idsRaw || !status) return { error: 'Dados inválidos.' }

  const ids = idsRaw.split(',').filter(Boolean)
  if (!ids.length) return { error: 'Nenhum livro selecionado.' }

  const validStatuses = ['reading', 'want_to_read', 'finished', 'abandoned']
  if (!validStatuses.includes(status)) return { error: 'Status inválido.' }

  const { error } = await supabase
    .from('books')
    .update({ status })
    .in('id', ids)
    .eq('user_id', user.id)   // RLS extra: garante que só atualiza os próprios

  if (error) return { error: error.message }

  revalidatePath('/library')
  return { updated: ids.length }
}

/** Remove múltiplos livros de uma vez */
export async function batchDelete(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const idsRaw = formData.get('ids') as string
  if (!idsRaw) return { error: 'Nenhum livro selecionado.' }

  const ids = idsRaw.split(',').filter(Boolean)
  if (!ids.length) return { error: 'Nenhum livro selecionado.' }

  const { error } = await supabase
    .from('books')
    .delete()
    .in('id', ids)
    .eq('user_id', user.id)

  if (error) return { error: error.message }

  revalidatePath('/library')
  return { deleted: ids.length }
}

/** Atualiza rating de um único livro */
export async function updateBookRating(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const bookId = formData.get('book_id') as string
  const rating = parseInt(formData.get('rating') as string)

  if (!bookId || isNaN(rating) || rating < 1 || rating > 5) {
    return { error: 'Dados inválidos.' }
  }

  const { error } = await supabase
    .from('books')
    .update({ rating })
    .eq('id', bookId)
    .eq('user_id', user.id)

  if (error) return { error: error.message }

  revalidatePath('/library')
  return { ok: true }
}
