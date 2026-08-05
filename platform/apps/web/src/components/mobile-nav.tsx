'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  HomeIcon,
  LibraryIcon,
  SearchIcon,
  SessionIcon,
  NotesIcon,
} from '@/lib/lumen-icons'

const items = [
  { href: '/', label: 'Início', icon: HomeIcon, exact: true },
  { href: '/library', label: 'Biblioteca', icon: LibraryIcon, exact: false },
  { href: '/library/search', label: 'Buscar', icon: SearchIcon, exact: false },
  { href: '/sessions', label: 'Sessões', icon: SessionIcon, exact: false },
  { href: '/notes', label: 'Notas', icon: NotesIcon, exact: false },
]

export function MobileNav() {
  const pathname = usePathname()

  return (
    <nav
      className="md:hidden fixed bottom-0 left-0 right-0 bg-[#FAF9F7] border-t border-[#ECEAE9] flex z-50"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
    >
      {items.map(({ href, label, icon: Icon, exact }) => {
        const active = exact ? pathname === href : pathname.startsWith(href)
        return (
          <Link
            key={href}
            href={href}
            className="flex-1 flex flex-col items-center gap-1 py-2.5 text-[#6B6863] transition-colors"
            aria-current={active ? 'page' : undefined}
          >
            <Icon
              className="h-5 w-5 flex-shrink-0"
              style={{ color: active ? '#1A1918' : undefined }}
            />
            <span
              className="text-[10px] leading-none"
              style={{ color: active ? '#1A1918' : undefined, fontWeight: active ? 600 : 400 }}
            >
              {label}
            </span>
          </Link>
        )
      })}
    </nav>
  )
}
