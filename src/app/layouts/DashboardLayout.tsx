import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { NavLink } from 'react-router'
import { Logo } from '@/components/shared/Logo'
import { cn } from '@/lib/utils'

export type DashboardNavItem = { to: string; label: string; icon: LucideIcon; end?: boolean }

type DashboardLayoutProps = {
  nav: DashboardNavItem[]
  area: string
  account: ReactNode
  children: ReactNode
}

/**
 * Shell for vendor and admin areas: a hairline-seamed sidebar on desktop and a bottom tab bar on phones.
 * Content is passed as children so the layout can host design previews and real routes alike.
 */
export function DashboardLayout({ nav, area, account, children }: DashboardLayoutProps) {
  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[16.5rem_1fr]">
      <a href="#dashboard-main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-primary focus:px-4 focus:py-2 focus:text-primary-foreground">
        Skip to content
      </a>
      <aside className="hidden border-r border-brass-line lg:flex lg:flex-col">
        <div className="flex h-[4.5rem] items-center border-b border-border px-6">
          <Logo />
        </div>
        <p className="px-6 pb-2 pt-6 text-xs font-semibold text-subtle-foreground">{area}</p>
        <nav aria-label={area} className="flex flex-col gap-0.5 px-3">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'flex h-11 items-center gap-3 rounded-md px-3 text-[0.9375rem] font-medium transition-colors duration-(--duration-fast) ease-(--ease-deco)',
                  isActive ? 'bg-surface-raised text-foreground [&_svg]:text-brass' : 'text-muted-foreground hover:bg-surface hover:text-foreground',
                )
              }
            >
              <Icon className="size-[1.125rem]" strokeWidth={1.5} aria-hidden />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="mt-auto border-t border-border p-4">{account}</div>
      </aside>
      <div className="flex min-w-0 flex-col pb-20 lg:pb-0">
        <header className="flex h-16 items-center justify-between border-b border-border px-4 lg:hidden">
          <Logo />
          {account}
        </header>
        <main id="dashboard-main" className="mx-auto w-full max-w-[76rem] flex-1 px-4 py-8 sm:px-8 lg:px-12 lg:py-12">
          {children}
        </main>
      </div>
      <nav aria-label={`${area} tabs`} className="fixed inset-x-0 bottom-0 z-30 grid border-t border-brass-line bg-background lg:hidden" style={{ gridTemplateColumns: `repeat(${nav.length}, minmax(0, 1fr))` }}>
        {nav.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) => cn('flex h-16 flex-col items-center justify-center gap-1 text-[0.6875rem] font-semibold', isActive ? 'text-brass' : 'text-muted-foreground')}
          >
            <Icon className="size-5" strokeWidth={1.5} aria-hidden />
            {label}
          </NavLink>
        ))}
      </nav>
    </div>
  )
}
