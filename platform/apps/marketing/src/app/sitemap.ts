import { createServerSupabase } from '@lumen/supabase/server'
import { MetadataRoute } from 'next'

/**
 * Sitemap dinâmico — spec §12
 *
 * Indexar:
 *   - Catálogo de livros  /books/[slug]
 *   - Autores             /authors/[slug]
 *   - Clubes públicos     /clubs/[id]
 *   - Perfis públicos     /@username
 *   - Landing / Download  /
 *
 * Nunca indexar: /app/**, /auth/**, admin/**
 */
export const revalidate = 3600 // re-gera o sitemap a cada hora

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = process.env.NEXT_PUBLIC_APP_URL ?? 'https://lumen.app'
  const supabase = await createServerSupabase()

  // Páginas estáticas
  const staticPages: MetadataRoute.Sitemap = [
    { url: base, lastModified: new Date(), changeFrequency: 'weekly', priority: 1 },
    { url: `${base}/download`, lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/blog`, lastModified: new Date(), changeFrequency: 'daily', priority: 0.7 },
  ]

  // Livros do catálogo
  const { data: books } = await supabase
    .from('book_catalog')
    .select('slug, updated_at')
    .order('updated_at', { ascending: false })
    .limit(5000)

  const bookUrls: MetadataRoute.Sitemap = (books ?? [])
    .filter((b) => b.slug)
    .map((b) => ({
      url: `${base}/books/${b.slug}`,
      lastModified: b.updated_at ? new Date(b.updated_at) : new Date(),
      changeFrequency: 'weekly',
      priority: 0.9,
    }))

  // Autores
  const { data: authors } = await supabase
    .from('authors')
    .select('slug, updated_at')
    .limit(2000)

  const authorUrls: MetadataRoute.Sitemap = (authors ?? [])
    .filter((a) => a.slug)
    .map((a) => ({
      url: `${base}/authors/${a.slug}`,
      lastModified: a.updated_at ? new Date(a.updated_at) : new Date(),
      changeFrequency: 'monthly',
      priority: 0.7,
    }))

  // Clubes públicos
  const { data: clubs } = await supabase
    .from('book_clubs')
    .select('id, slug, updated_at')
    .eq('status', 'active')
    .limit(2000)

  const clubUrls: MetadataRoute.Sitemap = (clubs ?? [])
    .map((c) => ({
      url: `${base}/clubs/${c.slug ?? c.id}`,
      lastModified: c.updated_at ? new Date(c.updated_at) : new Date(),
      changeFrequency: 'daily' as const,
      priority: 0.6,
    }))

  // Listas públicas
  const { data: lists } = await supabase
    .from('book_lists')
    .select('id, updated_at')
    .eq('visibility', 'public')
    .limit(5000)

  const listUrls: MetadataRoute.Sitemap = (lists ?? []).map((l) => ({
    url: `${base}/lists/${l.id}`,
    lastModified: l.updated_at ? new Date(l.updated_at) : new Date(),
    changeFrequency: 'weekly' as const,
    priority: 0.6,
  }))

  // Perfis públicos
  const { data: profiles } = await supabase
    .from('profiles')
    .select('username, updated_at')
    .eq('privacy_profile', 'public')
    .not('username', 'is', null)
    .limit(10000)

  const profileUrls: MetadataRoute.Sitemap = (profiles ?? [])
    .filter((p) => p.username)
    .map((p) => ({
      url: `${base}/@${p.username}`,
      lastModified: p.updated_at ? new Date(p.updated_at) : new Date(),
      changeFrequency: 'weekly' as const,
      priority: 0.5,
    }))

  return [...staticPages, ...bookUrls, ...authorUrls, ...clubUrls, ...listUrls, ...profileUrls]
}
