import { ArrowRight, BadgeCheck, SearchX } from 'lucide-react'
import { useId, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router'
import { EmptyState, Monogram, PriceTag, Rating, ServiceCover, VerifiedSeal } from '@/components/shared/marketplace'
import { DecoFrame, SlotPicker } from '@/components/shared/SlotPicker'
import { Button } from '@/components/ui/button'
import { NativeSelect } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { useCategories } from '@/features/categories/api'
import { useFeaturedServices, useNextFreeSlot } from '@/features/services/api'
import { serviceImageUrl } from '@/lib/supabase/storage'
import { dateInTimezone, formatDayLabel, formatDuration, formatSlotTime } from '@/lib/utils/time'

type Featured = NonNullable<ReturnType<typeof useFeaturedServices>['data']>[number]

export function HomePage() {
  const featured = useFeaturedServices(6)
  return (
    <>
      <section className="mx-auto grid max-w-[90rem] gap-12 px-4 pb-16 pt-12 sm:px-8 lg:grid-cols-12 lg:gap-16 lg:px-16 lg:pt-20">
        <div className="lg:col-span-7">
          <h1 className="font-display text-[2.75rem] font-medium leading-[1.06] tracking-[-0.02em] sm:text-6xl lg:text-display">
            Verified pros for <em className="pb-1 text-brass">every room</em> of your home.
          </h1>
          <p className="mt-6 max-w-[52ch] text-lg text-muted-foreground">
            Every professional is checked by our team before you can book them. You only see times they are free.
          </p>
          <HeroSearch />
        </div>
        <aside className="lg:col-span-5" aria-label="Next free pro">
          <NextFreeCard services={featured.data} isLoading={featured.isPending} isError={featured.isError} />
        </aside>
      </section>
      <CategoryBand />
      <FeaturedServices services={featured.data} isLoading={featured.isPending} />
      <VerificationSection />
    </>
  )
}

function HeroSearch() {
  const navigate = useNavigate()
  const categories = useCategories()
  const serviceId = useId()
  const whenId = useId()
  const [category, setCategory] = useState('')
  const [when, setWhen] = useState('today')

  function onSubmit(event: FormEvent) {
    event.preventDefault()
    const params = new URLSearchParams({ when })
    if (category) params.set('category', category)
    void navigate(`/services?${params.toString()}`)
  }

  return (
    <form onSubmit={onSubmit} role="search" className="mt-10 grid max-w-[44rem] gap-3 rounded-lg border border-brass-line bg-surface p-3 sm:grid-cols-[1.3fr_1fr_auto] sm:items-end">
      <div className="grid gap-1.5 px-1">
        <Label htmlFor={serviceId} className="text-xs text-muted-foreground">Service</Label>
        <NativeSelect id={serviceId} value={category} onChange={(e) => setCategory(e.target.value)} className="border-transparent bg-transparent px-0 text-base font-semibold hover:border-transparent">
          <option value="">All services</option>
          {categories.data?.map((c) => (
            <option key={c.slug} value={c.slug}>{c.name}</option>
          ))}
        </NativeSelect>
      </div>
      <div className="grid gap-1.5 border-border px-1 sm:border-l sm:pl-4">
        <Label htmlFor={whenId} className="text-xs text-muted-foreground">When</Label>
        <NativeSelect id={whenId} value={when} onChange={(e) => setWhen(e.target.value)} className="border-transparent bg-transparent px-0 text-base font-semibold hover:border-transparent">
          <option value="today">Today</option>
          <option value="tomorrow">Tomorrow</option>
          <option value="week">This week</option>
        </NativeSelect>
      </div>
      <Button type="submit" size="lg">Find a pro</Button>
    </form>
  )
}

function NextFreeCard({ services, isLoading, isError }: { services: Featured[] | null | undefined; isLoading: boolean; isError: boolean }) {
  const [slot, setSlot] = useState<string | null>(null)
  const [now] = useState(() => new Date())
  const dates = Array.from({ length: 7 }, (_, i) => dateInTimezone(now, undefined, i))
  const candidates = (services ?? []).slice(0, 4)
  const next = useNextFreeSlot(candidates.map((c) => c.id), dates)
  const service = candidates.find((c) => c.id === next.data?.serviceId)

  if (isLoading || (candidates.length > 0 && next.isPending)) {
    return (
      <DecoFrame>
        <div className="flex items-center gap-4">
          <Skeleton className="size-14 rounded-full" />
          <div className="grid flex-1 gap-2"><Skeleton className="h-6 w-2/3" /><Skeleton className="h-4 w-1/2" /></div>
        </div>
        <Skeleton className="mt-8 h-32" />
      </DecoFrame>
    )
  }

  if (isError || next.isError || !service || !next.data) {
    const failed = isError || next.isError
    const noPros = !failed && candidates.length === 0
    return (
      <EmptyState
        icon={<BadgeCheck strokeWidth={1.5} />}
        title={failed ? 'We could not load free times' : noPros ? 'Pros are being verified' : 'Every pro is booked this week'}
      >
        {failed
          ? 'Check your connection and refresh the page.'
          : noPros
            ? 'Verified pros will appear here as soon as our team approves them.'
            : 'New times open up as pros update their calendars. Browse services to request a later date.'}
      </EmptyState>
    )
  }

  const { date } = next.data
  const pickerSlots = next.data.slots.map((s) => ({ start: s.slot_start, label: formatSlotTime(s.slot_start), available: true }))
  const dayLabel = date === dates[0] ? 'Today' : date === dates[1] ? 'Tomorrow' : 'Next free day'
  const bookHref = `/services/${service.slug}?date=${date}${slot ? `&slot=${encodeURIComponent(slot)}` : ''}`

  return (
    <DecoFrame>
      <div className="flex items-center gap-4">
        <Monogram name={service.vendor_name} />
        <div className="min-w-0">
          <h2 className="truncate font-display text-2xl font-medium">{service.vendor_name}</h2>
          <VerifiedSeal />
        </div>
      </div>
      <div className="my-6 h-px bg-border" />
      <p className="font-semibold">{service.title}</p>
      <p className="mt-1 text-sm text-muted-foreground">
        {formatDuration(service.duration_minutes)} <span aria-hidden>·</span> <Rating value={service.avg_rating} count={service.review_count} />
      </p>
      <SlotPicker className="mt-6" label={`${dayLabel}, ${formatDayLabel(date)}`} slots={pickerSlots.slice(0, 8)} value={slot} onChange={setSlot} />
      <div className="mt-6 flex items-end justify-between gap-4">
        <PriceTag paise={service.price_paise} className="text-3xl" />
        <Button asChild size="lg">
          <Link to={bookHref}>{slot ? `Book ${formatSlotTime(slot)}` : 'All times'}</Link>
        </Button>
      </div>
    </DecoFrame>
  )
}

function CategoryBand() {
  const { data, isPending } = useCategories()
  return (
    <section aria-label="Categories" className="mx-auto max-w-[90rem] px-4 sm:px-8 lg:px-16">
      <ul data-testid="category-list" className="grid grid-cols-2 border-y border-brass-line sm:grid-cols-3 lg:grid-cols-6">
        {isPending
          ? Array.from({ length: 6 }, (_, i) => (
              <li key={i} className="border-border p-6 [&:not(:last-child)]:border-r"><Skeleton className="h-7 w-24" /></li>
            ))
          : data?.map((c) => (
              <li key={c.slug} className="border-b border-border last:border-b-0 sm:border-b-0 [&:not(:last-child)]:border-r">
                <Link to={`/services?category=${c.slug}`} className="group flex items-center justify-between gap-2 p-6 transition-colors duration-(--duration-fast) ease-(--ease-deco) hover:bg-surface">
                  <span className="font-display text-2xl font-medium">{c.name}</span>
                  <ArrowRight className="size-4 text-brass opacity-0 transition-[opacity,transform] duration-(--duration-base) ease-(--ease-deco) group-hover:translate-x-0.5 group-hover:opacity-100" strokeWidth={1.5} aria-hidden />
                </Link>
              </li>
            ))}
      </ul>
    </section>
  )
}

function FeaturedServices({ services, isLoading }: { services: Featured[] | null | undefined; isLoading: boolean }) {
  return (
    <section className="mx-auto max-w-[90rem] px-4 py-20 sm:px-8 lg:px-16 lg:py-28">
      <div className="flex items-end justify-between gap-6">
        <h2 className="font-display text-4xl font-medium sm:text-5xl">Newly verified services</h2>
        <Link to="/services" className="hidden shrink-0 text-sm font-semibold text-brass underline decoration-brass-line hover:decoration-brass sm:inline">All services</Link>
      </div>
      {isLoading ? (
        <div className="mt-10 grid gap-x-12 gap-y-2 md:grid-cols-2">
          {Array.from({ length: 4 }, (_, i) => <Skeleton key={i} className="h-28" />)}
        </div>
      ) : !services?.length ? (
        <EmptyState className="mt-10" icon={<SearchX strokeWidth={1.5} />} title="No services yet">
          Services appear here once their pro is verified by the Veny team.
        </EmptyState>
      ) : (
        <ul className="mt-10 grid gap-x-12 md:grid-cols-2">
          {services.map((s) => (
            <li key={s.id} className="border-b border-border">
              <Link to={`/services/${s.slug}`} className="group grid grid-cols-[5.5rem_1fr_auto] items-center gap-5 py-5">
                <div className="aspect-square overflow-hidden rounded-md border border-border">
                  <ServiceCover src={serviceImageUrl(s.cover_path)} title={s.title} category={s.category_slug} className="p-3 [&>span:first-child]:text-3xl [&>span:last-child]:hidden" />
                </div>
                <div className="min-w-0">
                  <p className="truncate text-lg font-semibold transition-colors group-hover:text-brass">{s.title}</p>
                  <p className="truncate text-sm text-muted-foreground">{s.vendor_name}, {formatDuration(s.duration_minutes)}</p>
                  <Rating className="mt-1" value={s.avg_rating} count={s.review_count} />
                </div>
                <PriceTag paise={s.price_paise} />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

const verificationSteps = [
  { title: 'Pros apply with documents', body: 'Every pro submits identity and business documents before they can list a service.' },
  { title: 'Our team reviews them', body: 'A Veny admin checks each application by hand and approves or declines it with a note.' },
  { title: 'You book real free times', body: 'Only approved pros appear, and only at times their calendar is actually open.' },
]

const tierClass = ['md:mt-24', 'md:mt-12 md:border-l md:border-l-brass-line md:pl-8', 'md:border-l md:border-l-brass-line md:pl-8']

/** The three steps rise like the stepped Deco mark: each tier sits higher than the one before. */
function VerificationSection() {
  return (
    <section id="verification" className="scroll-mt-24 border-t border-brass-line bg-surface">
      <div className="mx-auto max-w-[90rem] px-4 py-20 sm:px-8 lg:px-16 lg:py-28">
        <h2 className="max-w-[18ch] font-display text-4xl font-medium sm:text-5xl">How a pro earns the Veny seal</h2>
        <ol className="mt-14 grid gap-10 md:grid-cols-3 md:items-start md:gap-0">
          {verificationSteps.map(({ title, body }, i) => (
            <li key={title} className={`border-t-2 border-brass pt-6 md:pr-10 ${tierClass[i]}`}>
              <span aria-hidden className="font-display text-6xl font-medium italic leading-none text-brass">{i + 1}</span>
              <h3 className="mt-4 font-display text-2xl font-medium">{title}</h3>
              <p className="mt-2 max-w-[38ch] text-muted-foreground">{body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}
