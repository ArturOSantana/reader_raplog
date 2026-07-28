'use server'

import { redirect } from 'next/navigation'
import { createServerSupabase } from '@lumen/supabase/server'

/** Adiciona um livro encontrado na busca à biblioteca do usuário */
export async function addBookFromSearch(formData: FormData) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const title         = (formData.get('title') as string)?.trim()
  const author        = (formData.get('author') as string)?.trim() || null
  const coverUrl      = (formData.get('cover_url') as string)?.trim() || null
  const isbn          = (formData.get('isbn') as string)?.trim() || null
  const publisher     = (formData.get('publisher') as string)?.trim() || null
  const publishedYear = parseInt(formData.get('published_year') as string) || null
  const pageCount     = parseInt(formData.get('page_count') as string) || null
  const googleBooksId = (formData.get('google_books_id') as string)?.trim() || null
  const redirectQ     = (formData.get('redirect_q') as string) ?? ''

  if (!title) {
    redirect(`/library/search?q=${encodeURIComponent(redirectQ)}&error=titulo`)
  }

  // Verifica se já existe na biblioteca
  if (googleBooksId) {
    const { data: existing } = await supabase
      .from('books')
      .select('id')
      .eq('user_id', user.id)
      .eq('google_books_id', googleBooksId)
      .single()

    if (existing) {
      redirect(`/library/search?q=${encodeURIComponent(redirectQ)}&action=added&added=${encodeURIComponent(title + ' (já na biblioteca)')}`)
    }
  }

  const { error } = await supabase.from('books').insert({
    user_id:        user.id,
    title,
    author,
    cover_url:      coverUrl,
    isbn,
    publisher,
    published_year: publishedYear,
    page_count:     pageCount,
    google_books_id: googleBooksId,
    status:         'want_to_read',
    current_page:   0,
  })

  if (error) {
    redirect(`/library/search?q=${encodeURIComponent(redirectQ)}&error=save`)
  }

  redirect(`/library/search?q=${encodeURIComponent(redirectQ)}&action=added&added=${encodeURIComponent(title)}`)
}
