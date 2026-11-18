import { Menu, X } from 'lucide-react'
import { Dialog as DialogPrimitive } from 'radix-ui'
import { useState } from 'react'
import { Link, NavLink, Outlet } from 'react-router'
import { Logo, LogoMark } from '@/components/shared/Logo'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/services', label: 'Services' },
  { to: '/#verification', label: 'How verification works' },
  { to: '/signup?role=vendor', label: 'Become a pro' },
]

function navClass({ isActive }: { isActive: boolean }) {
  return cn(
    'rounded-sm text-[0.9375rem] font-medium transition-colors duration-(--duration-fast) ease-(--ease-deco) hover:text-foreground',
    isActive ? 'text-foreground' : 'text-muted-foreground',
  )
}

export function PublicLayout() {
  const [open, setOpen] = useState(false)
  return (
    <div className="flex min-h-dvh flex-col">
      <a href="#main" className="sr-only rounded-md bg-primary px-4 py-2 text-primary-foreground focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50">
        Skip to content
      </a>
      <header className="sticky top-0 z-30 border-b border-brass-line bg-background">
        <div className="mx-auto flex h-[4.5rem] max-w-[90rem] items-center gap-10 px-4 sm:px-8 lg:px-16">
          <Logo />
          <nav aria-label="Main" className="hidden items-center gap-8 lg:flex">
            {navItems.map((item) => (
              <NavLink key={item.to} to={item.to} className={(state) => navClass({ isActive: state.isActive && !item.to.includes('#') && !item.to.includes('?') })} end>
                {item.label}
              </NavLink>
            ))}
          </nav>
          <div className="ml-auto hidden items-center gap-2 sm:flex">
            <Button asChild variant="ghost">
              <Link to="/login">Log in</Link>
            </Button>
            <Button asChild>
              <Link to="/signup">Sign up</Link>
            </Button>
          </div>
          <DialogPrimitive.Root open={open} onOpenChange={setOpen}>
            <DialogPrimitive.Trigger asChild>
              <Button variant="ghost" size="icon" className="ml-auto sm:ml-0 lg:hidden" aria-label="Open menu">
                <Menu className="size-5" strokeWidth={1.75} />
              </Button>
            </DialogPrimitive.Trigger>
            <DialogPrimitive.Portal>
              <DialogPrimitive.Overlay className="fixed inset-0 z-40 bg-overlay data-[state=open]:animate-in data-[state=open]:fade-in-0" />
              <DialogPrimitive.Content className="fixed inset-x-0 top-0 z-50 border-b border-brass-line bg-background px-4 pb-8 pt-4 duration-(--duration-slow) data-[state=open]:animate-in data-[state=open]:slide-in-from-top-4 sm:px-8">
                <div className="flex h-10 items-center justify-between">
                  <DialogPrimitive.Title className="flex items-center gap-3 font-display text-xl tracking-[0.18em]">
                    <LogoMark className="size-5" />
                    VENY
                  </DialogPrimitive.Title>
                  <DialogPrimitive.Close asChild>
                    <Button variant="ghost" size="icon" aria-label="Close menu">
                      <X className="size-5" strokeWidth={1.75} />
                    </Button>
                  </DialogPrimitive.Close>
                </div>
                <DialogPrimitive.Description className="sr-only">Site navigation</DialogPrimitive.Description>
                <nav aria-label="Mobile" className="mt-6 flex flex-col">
                  {navItems.map((item) => (
                    <Link key={item.to} to={item.to} onClick={() => setOpen(false)} className="border-b border-border py-4 font-display text-2xl">
                      {item.label}
                    </Link>
                  ))}
                </nav>
                <div className="mt-6 grid grid-cols-2 gap-3">
                  <Button asChild variant="secondary" size="lg">
                    <Link to="/login" onClick={() => setOpen(false)}>Log in</Link>
                  </Button>
                  <Button asChild size="lg">
                    <Link to="/signup" onClick={() => setOpen(false)}>Sign up</Link>
                  </Button>
                </div>
              </DialogPrimitive.Content>
            </DialogPrimitive.Portal>
          </DialogPrimitive.Root>
        </div>
      </header>
      <main id="main" className="flex-1">
        <Outlet />
      </main>
      <footer className="border-t border-brass-line">
        <div className="mx-auto flex max-w-[90rem] flex-col gap-6 px-4 py-10 sm:flex-row sm:items-center sm:justify-between sm:px-8 lg:px-16">
          <div>
            <Logo />
            <p className="mt-3 text-sm text-muted-foreground">The Elite Marketplace. Verified pros, real availability, pay on-site.</p>
          </div>
          <nav aria-label="Footer" className="flex flex-wrap gap-x-8 gap-y-3 text-sm text-muted-foreground">
            <Link to="/services" className="hover:text-foreground">Services</Link>
            <Link to="/signup?role=vendor" className="hover:text-foreground">Become a pro</Link>
            <Link to="/login" className="hover:text-foreground">Log in</Link>
          </nav>
        </div>
      </footer>
    </div>
  )
}
