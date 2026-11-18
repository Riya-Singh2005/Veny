import { ShieldCheck, Star } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Badge } from '@/components/ui/badge'
import type { Enums } from '@/lib/supabase/client'
import { cn, formatPrice } from '@/lib/utils'

export function VerifiedSeal({ className }: { className?: string }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 text-[0.8125rem] font-bold text-brass', className)}>
      <ShieldCheck className="size-4" strokeWidth={1.75} aria-hidden />
      Verified by Veny
    </span>
  )
}

export function Rating({ value, count, className }: { value: number; count: number; className?: string }) {
  if (count === 0) return <span className={cn('text-sm text-muted-foreground', className)}>New on Veny</span>
  return (
    <span className={cn('inline-flex items-center gap-1 text-sm text-muted-foreground', className)}>
      <Star className="size-3.5 fill-brass text-brass" strokeWidth={1.5} aria-hidden />
      <span className="font-semibold text-foreground">{value.toFixed(1)}</span>
      <span>({count} {count === 1 ? 'review' : 'reviews'})</span>
    </span>
  )
}

export function PriceTag({ paise, className, suffix }: { paise: number; className?: string; suffix?: string }) {
  return (
    <span className={cn('font-display text-2xl font-medium leading-none', className)}>
      {formatPrice(paise)}
      {suffix ? <span className="ml-1 font-sans text-sm font-medium text-muted-foreground">{suffix}</span> : null}
    </span>
  )
}

type BookingStatus = Enums<'booking_status'>

const statusMeta: Record<BookingStatus, { label: string; tone: 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'brass' }> = {
  pending: { label: 'Awaiting pro', tone: 'warning' },
  confirmed: { label: 'Confirmed', tone: 'info' },
  in_progress: { label: 'In progress', tone: 'brass' },
  completed: { label: 'Completed', tone: 'success' },
  cancelled: { label: 'Cancelled', tone: 'neutral' },
  rejected: { label: 'Declined', tone: 'danger' },
}

export function StatusBadge({ status, className }: { status: BookingStatus; className?: string }) {
  const meta = statusMeta[status]
  return (
    <Badge tone={meta.tone} className={className}>
      {meta.label}
    </Badge>
  )
}

export function PageHeader({ title, description, actions, className }: { title: string; description?: ReactNode; actions?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between', className)}>
      <div>
        <h1 className="font-display text-4xl font-medium tracking-[-0.01em] sm:text-5xl">{title}</h1>
        {description ? <p className="mt-2 max-w-[60ch] text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
    </div>
  )
}

export function EmptyState({ icon, title, children, action, className }: { icon?: ReactNode; title: string; children?: ReactNode; action?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex flex-col items-start gap-3 rounded-lg border border-dashed border-brass-line px-6 py-10 sm:px-10', className)}>
      {icon ? <div className="text-brass [&_svg]:size-6">{icon}</div> : null}
      <h2 className="font-display text-2xl font-medium">{title}</h2>
      {children ? <div className="max-w-[52ch] text-muted-foreground">{children}</div> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  )
}

/** Initial-letter monogram for a pro without a photo. */
export function Monogram({ name, className }: { name: string; className?: string }) {
  return (
    <span aria-hidden className={cn('grid size-14 shrink-0 place-items-center rounded-full border border-brass-line bg-surface-raised font-display text-2xl italic text-brass', className)}>
      {name.trim().charAt(0).toUpperCase()}
    </span>
  )
}

/** Cover image for a service, or an honest typographic placeholder when the vendor has not uploaded one. */
export function ServiceCover({ src, title, category, className }: { src?: string | null; title: string; category?: string; className?: string }) {
  const [failed, setFailed] = useState(false)
  if (src && !failed) return <img src={src} alt={title} loading="lazy" onError={() => setFailed(true)} className={cn('size-full object-cover', className)} />
  return (
    <div className={cn('flex size-full flex-col justify-end bg-surface-raised p-5', className)} role="img" aria-label={`${title}, no photo yet`}>
      <span className="font-display text-5xl font-medium italic leading-none text-brass/80">{(category ?? title).charAt(0).toUpperCase()}</span>
      {category ? <span className="mt-2 text-xs font-semibold text-muted-foreground">{category}</span> : null}
    </div>
  )
}
