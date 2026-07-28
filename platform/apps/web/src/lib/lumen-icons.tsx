import type { SVGProps } from 'react'

const INK = '#1A1918'
const INK_LIGHT = '#EFEFED'
const PROGRESS = '#4D7056'

type IconProps = SVGProps<SVGSVGElement> & {
  title?: string
}

type DecorativeProps = SVGProps<SVGSVGElement> & {
  title?: string
  variant?: 'light' | 'dark'
}

function iconProps({
  title,
  viewBox = '0 0 24 24',
  ...props
}: IconProps & { viewBox?: string }) {
  return {
    viewBox,
    fill: 'none',
    xmlns: 'http://www.w3.org/2000/svg',
    stroke: 'currentColor',
    strokeWidth: 1.75,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    role: title ? ('img' as const) : undefined,
    'aria-hidden': title ? undefined : true,
    ...props,
  }
}

export function HomeIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <path d="M3.75 10.5 12 4.5l8.25 6" />
      <path d="M6.5 9.75v9.75h11V9.75" />
    </svg>
  )
}

export function LibraryIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <path d="M5.5 4.75h3.25v14.5H5.5z" />
      <path d="M10.25 4.75h4.25v14.5h-4.25z" />
      <path d="M16 4.75h2.5v14.5H16z" />
      <path d="M4 19.25h16" />
    </svg>
  )
}

export function SessionIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <circle cx="12" cy="12" r="7" />
      <path d="M12 8v4.5l2.75 1.75" />
    </svg>
  )
}

export function NotesIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <rect x="4.5" y="4.5" width="15" height="15" rx="1.75" />
      <path d="M8 8.5h8" />
      <path d="M8 12h8" />
      <path d="M8 15.5h5" />
    </svg>
  )
}

export function SearchIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <circle cx="11" cy="11" r="5.75" />
      <path d="m16 16 3.5 3.5" />
    </svg>
  )
}

export function AddIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <path d="M12 5v14" />
      <path d="M5 12h14" />
    </svg>
  )
}

export function CalendarIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <rect x="4.5" y="6.5" width="15" height="13" rx="1.75" />
      <path d="M8 4.5v4" />
      <path d="M16 4.5v4" />
      <path d="M4.5 10h15" />
    </svg>
  )
}

export function SettingsIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <circle cx="12" cy="12" r="3" />
      <path d="M12 4.75v1.5" />
      <path d="M12 17.75v1.5" />
      <path d="M6.87 6.87 7.93 7.93" />
      <path d="M16.07 16.07l1.06 1.06" />
      <path d="M4.75 12h1.5" />
      <path d="M17.75 12h1.5" />
      <path d="M6.87 17.13l1.06-1.06" />
      <path d="m16.07 7.93 1.06-1.06" />
    </svg>
  )
}

export function ChevronRightIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <path d="m9 6.75 5 5.25L9 17.25" />
    </svg>
  )
}

export function ProfileIcon({ title, ...props }: IconProps) {
  return (
    <svg {...iconProps({ title, ...props })}>
      {title ? <title>{title}</title> : null}
      <circle cx="12" cy="8.5" r="3.25" />
      <path d="M5.75 18.5c1.2-2.5 3.28-3.75 6.25-3.75s5.05 1.25 6.25 3.75" />
    </svg>
  )
}

export function LumenQuoteGlyph({ title, ...props }: DecorativeProps) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      {...props}
    >
      {title ? <title>{title}</title> : null}
      <path d="M9 10.5c-2 2.1-3 4.2-3 6.6 0 2.5 1.4 4.4 3.8 4.4 2.1 0 3.7-1.5 3.7-3.7 0-2-1.3-3.3-3.2-3.6.1-1.3.8-2.6 2.2-4.2L9 10.5Z" fill={INK} />
      <path d="M20 10.5c-2 2.1-3 4.2-3 6.6 0 2.5 1.4 4.4 3.8 4.4 2.1 0 3.7-1.5 3.7-3.7 0-2-1.3-3.3-3.2-3.6.1-1.3.8-2.6 2.2-4.2L20 10.5Z" fill={PROGRESS} />
    </svg>
  )
}

export function LumenMark({ title, variant = 'light', ...props }: DecorativeProps) {
  const stroke = variant === 'dark' ? INK_LIGHT : INK

  return (
    <svg
      viewBox="0 0 40 40"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      {...props}
    >
      {title ? <title>{title}</title> : null}
      <path d="M7 5 L7 29 L22 29" stroke={stroke} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
      <line x1="7" y1="34" x2="31" y2="34" stroke={PROGRESS} strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="35" cy="34" r="2.8" fill={PROGRESS} />
    </svg>
  )
}
