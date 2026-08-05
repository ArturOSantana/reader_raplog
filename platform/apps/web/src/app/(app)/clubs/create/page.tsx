import { redirect } from 'next/navigation'
import Link from 'next/link'
import { createServerSupabase } from '@lumen/supabase/server'
import { createClub } from '../club-actions'
import { clubCategoryLabel } from '@lumen/ui'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Criar Clube · Lumen' }

const CATEGORIES = [
  'general','fiction','nonfiction','fantasy','scifi',
  'romance','mystery','biography','history','selfhelp','children','classics',
]

interface PageProps {
  searchParams: Promise<{ error?: string }>
}

export default async function CreateClubPage({ searchParams }: PageProps) {
  const supabase = await createServerSupabase()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { error } = await searchParams

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <Link href="/clubs" className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] hover:text-[#1A1918] mb-4 inline-block">
        ← Clubes
      </Link>
      <p className="text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-1">Clubes</p>
      <h1 className="font-[Fraunces] text-3xl font-bold text-[#1A1918] mb-8">Criar clube</h1>

      {error && (
        <div className="mb-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm font-[IBM_Plex_Mono]">
          {error}
        </div>
      )}

      <form action={async (fd) => {
        'use server'
        const result = await createClub(fd)
        if (result?.error) {
          redirect(`/clubs/create?error=${encodeURIComponent(result.error)}`)
        }
      }} className="bg-[#FAF9F7] border border-[#ECEAE9] rounded-2xl p-6 space-y-5">
        <div>
          <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
            Nome do clube *
          </label>
          <input
            name="name"
            required
            minLength={3}
            maxLength={60}
            placeholder="Ex: Amantes de Ficção Científica"
            className="w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#3D6B5A]"
          />
        </div>

        <div>
          <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
            Descrição
          </label>
          <textarea
            name="description"
            rows={3}
            maxLength={500}
            placeholder="Sobre o que é seu clube?"
            className="w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#3D6B5A] resize-none"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
              Categoria
            </label>
            <select
              name="category"
              defaultValue="general"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm bg-[#FAF9F7] focus:outline-none focus:border-[#3D6B5A]"
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>{clubCategoryLabel(c)}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-[IBM_Plex_Mono] text-[#6B6863] uppercase tracking-widest mb-2">
              Visibilidade
            </label>
            <select
              name="visibility"
              defaultValue="public"
              className="w-full border border-[#ECEAE9] rounded-xl px-4 py-3 text-sm bg-[#FAF9F7] focus:outline-none focus:border-[#3D6B5A]"
            >
              <option value="public">Público</option>
              <option value="private">Privado</option>
              <option value="invite_only">Apenas convite</option>
            </select>
          </div>
        </div>

        <button
          type="submit"
          className="w-full bg-[#1A1918] text-white py-3 rounded-xl text-sm font-medium hover:bg-[#3D6B5A] transition-colors"
        >
          Criar clube
        </button>
      </form>
    </div>
  )
}
