import { ArrowRight, Inbox } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router'
import { LogoMark } from '@/components/shared/Logo'
import { EmptyState, PriceTag, Rating, StatusBadge, VerifiedSeal } from '@/components/shared/marketplace'
import { DecoFrame, SlotPicker } from '@/components/shared/SlotPicker'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input, Textarea } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { previewSlots } from './fixtures'

const swatches = [
  { name: 'Background', className: 'bg-background' },
  { name: 'Surface', className: 'bg-surface' },
  { name: 'Raised', className: 'bg-surface-raised' },
  { name: 'Brass', className: 'bg-brass' },
  { name: 'Brass line', className: 'bg-brass-line' },
  { name: 'Primary', className: 'bg-primary' },
  { name: 'Success', className: 'bg-success' },
  { name: 'Warning', className: 'bg-warning' },
  { name: 'Destructive', className: 'bg-destructive' },
]

const screens = [
  { to: '/', title: 'Home', body: 'Live data: categories, newly verified services and real free times.' },
  { to: '/design/service', title: 'Service detail', body: 'Booking panel in the Deco frame; full-screen photo on phones.' },
  { to: '/design/vendor', title: 'Vendor workspace', body: 'Requests with isolated Decline, and the day as time-ranked rows.' },
]

export function DesignSystemPage() {
  const [slot, setSlot] = useState<string | null>(null)
  const [theme, setTheme] = useState<'dark' | 'light'>('dark')

  return (
    <div data-theme={theme} className="bg-background text-foreground">
      <div className="mx-auto max-w-[90rem] px-4 py-14 sm:px-8 lg:px-16">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <h1 className="font-display text-5xl font-medium sm:text-6xl">Bombay Deco Nights</h1>
            <p className="mt-3 max-w-[60ch] text-muted-foreground">The Veny design system. Ink-violet ground, brass hairlines, amethyst for primary actions, Bodoni Moda with Manrope.</p>
          </div>
          <div className="flex gap-2" role="group" aria-label="Theme">
            <Button variant={theme === 'dark' ? 'secondary' : 'ghost'} aria-pressed={theme === 'dark'} onClick={() => setTheme('dark')}>Dark</Button>
            <Button variant={theme === 'light' ? 'secondary' : 'ghost'} aria-pressed={theme === 'light'} onClick={() => setTheme('light')}>Light</Button>
          </div>
        </div>

        <h2 className="mt-14 font-display text-3xl font-medium">Key screens</h2>
        <ul className="mt-5 grid border-y border-brass-line md:grid-cols-3">
          {screens.map((s) => (
            <li key={s.to} className="border-border md:[&:not(:last-child)]:border-r">
              <Link to={s.to} className="group block p-6 transition-colors duration-(--duration-fast) ease-(--ease-deco) hover:bg-surface">
                <span className="flex items-center justify-between font-display text-2xl">{s.title}<ArrowRight className="size-4 text-brass transition-transform duration-(--duration-base) ease-(--ease-deco) group-hover:translate-x-1" strokeWidth={1.5} aria-hidden /></span>
                <span className="mt-2 block text-sm text-muted-foreground">{s.body}</span>
              </Link>
            </li>
          ))}
        </ul>

        <div className="mt-14 grid gap-14 lg:grid-cols-2">
          <section>
            <h2 className="font-display text-3xl font-medium">Colour</h2>
            <ul className="mt-5 grid grid-cols-3 gap-3">
              {swatches.map((s) => (
                <li key={s.name}>
                  <div className={`h-16 rounded-md border border-border ${s.className}`} />
                  <p className="mt-2 text-sm text-muted-foreground">{s.name}</p>
                </li>
              ))}
            </ul>
          </section>
          <section>
            <h2 className="font-display text-3xl font-medium">Type</h2>
            <div className="mt-5 space-y-4">
              <p className="font-display text-6xl font-medium leading-none">Display 76</p>
              <p className="font-display text-4xl font-medium">Heading, Bodoni Moda</p>
              <p className="text-lg">Body, Manrope. Every pro is verified before you can book them.</p>
              <p className="text-sm text-muted-foreground">Secondary text 14 with tabular numerals 10:30 14:00 ₹1,499</p>
              <div className="flex items-center gap-4"><LogoMark /><PriceTag paise={149900} /><Rating value={4.8} count={37} /><VerifiedSeal /></div>
            </div>
          </section>
          <section>
            <h2 className="font-display text-3xl font-medium">Actions</h2>
            <div className="mt-5 flex flex-wrap items-center gap-3">
              <Button>Book 16:30</Button>
              <Button variant="secondary">Reschedule</Button>
              <Button variant="outline">Message pro</Button>
              <Button variant="ghost">Skip</Button>
              <Button variant="link">View details</Button>
              <Button disabled>Disabled</Button>
            </div>
            <div className="mt-6 flex items-center justify-between rounded-md border border-border p-4">
              <Button>Accept</Button>
              <Button variant="destructive" size="sm">Decline</Button>
            </div>
            <div className="mt-6 flex flex-wrap gap-2">
              <StatusBadge status="pending" /><StatusBadge status="confirmed" /><StatusBadge status="in_progress" /><StatusBadge status="completed" /><StatusBadge status="cancelled" /><StatusBadge status="rejected" /><Badge tone="brass">Verified</Badge>
            </div>
          </section>
          <section>
            <h2 className="font-display text-3xl font-medium">Fields</h2>
            <div className="mt-5 grid gap-5">
              <div className="grid gap-1.5"><Label htmlFor="ds-name">Full name</Label><Input id="ds-name" placeholder="Neha Iyer" autoComplete="name" /></div>
              <div className="grid gap-1.5">
                <Label htmlFor="ds-phone">Phone</Label>
                <Input id="ds-phone" aria-invalid aria-describedby="ds-phone-err" defaultValue="98450" inputMode="tel" />
                <p id="ds-phone-err" className="text-sm text-destructive">Enter a 10-digit mobile number.</p>
              </div>
              <div className="grid gap-1.5"><Label htmlFor="ds-note">Note for the pro</Label><Textarea id="ds-note" placeholder="Gate code, parking, anything useful" /></div>
            </div>
          </section>
          <section>
            <h2 className="font-display text-3xl font-medium">Signature: slot picker</h2>
            <DecoFrame className="mt-5">
              <SlotPicker label="Free times, Thu 19 Nov" slots={previewSlots} value={slot} onChange={setSlot} />
            </DecoFrame>
          </section>
          <section>
            <h2 className="font-display text-3xl font-medium">States</h2>
            <div className="mt-5 grid gap-5">
              <div className="flex items-center gap-4"><Skeleton className="size-14 rounded-full" /><div className="grid flex-1 gap-2"><Skeleton className="h-5 w-1/2" /><Skeleton className="h-4 w-1/3" /></div></div>
              <EmptyState icon={<Inbox strokeWidth={1.5} />} title="No bookings yet" action={<Button asChild><Link to="/">Find a pro</Link></Button>}>
                When you book a pro, the request and its status appear here.
              </EmptyState>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
