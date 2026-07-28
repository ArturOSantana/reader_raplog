/**
 * @lumen/ui
 *
 * Utilitários compartilhados entre as apps do Lumen.
 */

import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { formatDistanceToNow, format } from 'date-fns'
import { ptBR } from 'date-fns/locale'

/** Combina classes Tailwind sem conflitos. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** Formata data relativa: "há 3 dias". */
export function timeAgo(dateStr: string) {
  return formatDistanceToNow(new Date(dateStr), { addSuffix: true, locale: ptBR })
}

/** Formata data completa: "15 jan. 2025". */
export function formatDate(dateStr: string) {
  return format(new Date(dateStr), 'd MMM. yyyy', { locale: ptBR })
}

/** Formata minutos → "2h 30min". */
export function formatMinutes(minutes: number): string {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  if (h === 0) return `${m}min`
  if (m === 0) return `${h}h`
  return `${h}h ${m}min`
}

/** Retorna iniciais de um nome. */
export function initials(name: string): string {
  return name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('')
}

/** Slug seguro para URLs. */
export function slugify(str: string): string {
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
}

/** URL de avatar — fallback para UI Avatars. */
export function avatarUrl(url: string | null | undefined, name: string): string {
  if (url) return url
  const initStr = initials(name || 'U')
  return `https://ui-avatars.com/api/?name=${initStr}&background=3D6B5A&color=FAF9F7&size=128&bold=true`
}

/** Rótulo legível para status de livro. */
export function bookStatusLabel(status: string): string {
  const map: Record<string, string> = {
    reading: 'Lendo',
    want_to_read: 'Quero ler',
    read: 'Lido',
    abandoned: 'Abandonado',
  }
  return map[status] ?? status
}

/** Rótulo de categoria de clube. */
export function clubCategoryLabel(cat: string): string {
  const map: Record<string, string> = {
    general: 'Geral',
    fiction: 'Ficção',
    nonfiction: 'Não-ficção',
    fantasy: 'Fantasia',
    scifi: 'Ficção Científica',
    romance: 'Romance',
    mystery: 'Mistério',
    biography: 'Biografia',
    history: 'História',
    selfhelp: 'Autoajuda',
    children: 'Infantil',
    classics: 'Clássicos',
  }
  return map[cat] ?? cat
}

/**
 * Renderiza uma string de estrelas para rating 1-5.
 *
 * @param rating - Valor numérico de 1 a 5 (0 retorna string vazia)
 * @param withEmpty - Se `true`, preenche estrelas vazias até 5 (padrão: true)
 * @returns Exemplo: starRating(3) → "★★★☆☆"
 */
export function starRating(rating: number, withEmpty = true): string {
  const clamped = Math.max(0, Math.min(5, Math.round(rating)))
  if (clamped === 0) return ''
  const filled = '★'.repeat(clamped)
  const empty = withEmpty ? '☆'.repeat(5 - clamped) : ''
  return filled + empty
}
