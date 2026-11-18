import { Check, ChevronRight, MapPin, Star } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router'
import { Monogram, PriceTag, Rating, ServiceCover, VerifiedSeal } from '@/components/shared/marketplace'
import { DecoFrame, SlotPicker } from '@/components/shared/SlotPicker'
import { Button } from '@/components/ui/button'
import { NativeSelect } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn } from '@/lib/utils'
import { formatDayLabel, formatDuration } from '@/lib/utils/time'
import { previewDays, previewService as s, previewSlots } from './fixtures'
import { PreviewBanner } from './PreviewBanner'

export function ServicePreviewPage() {
  const [day, setDay] = useState(previewDays[0]!)
  const [slot, setSlot] = useState<string | null>(previewSlots[7]!.start)
  const slotLabel = previewSlots.find((x) => x.start === slot)?.label
  // The sample service has no photo yet; M4 reads cover_path from the service.
  const coverUrl: string | null = null
  const hasPhoto = coverUrl !== null

  return (
    <>
      <PreviewBanner milestone="M4" />
      <div className="mx-auto max-w-[90rem] px-4 pb-32 sm:px-8 lg:px-16 lg:pb-24">
        <nav aria-label="Breadcrumb" className="hidden items-center gap-2 py-6 text-sm text-muted-foreground sm:flex">
          <Link to="/services" className="hover:text-foreground">Services</Link>
          <ChevronRight className="size-3.5" strokeWidth={1.5} aria-hidden />
          <span>{s.category}</span>
        </nav>
        <div className="grid grid-cols-[minmax(0,1fr)] gap-12 lg:grid-cols-12 lg:gap-16">
          <article className="min-w-0 lg:col-span-7">
            {/* With a photo it owns the first screen on phones (4:5). Without one, a short band keeps title, pro and seal in view. */}
            <div className={cn('-mx-4 overflow-hidden border-b border-brass-line sm:mx-0 sm:rounded-lg sm:border', hasPhoto ? 'aspect-[4/5] sm:aspect-[16/10]' : 'h-32 sm:h-48')}>
              <ServiceCover src={coverUrl} title={s.title} category={s.category} className="p-6 [&>span:first-child]:text-5xl" />
            </div>
            <h1 className="mt-8 font-display text-4xl font-medium leading-tight sm:text-5xl">{s.title}</h1>
            <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2">
              <Rating value={s.rating} count={s.reviewCount} />
              <span className="text-sm text-muted-foreground">{formatDuration(s.durationMinutes)}</span>
              <span className="inline-flex items-center gap-1.5 text-sm text-muted-foreground"><MapPin className="size-3.5" strokeWidth={1.5} aria-hidden />{s.area}</span>
            </div>
            <div className="mt-8 flex items-center gap-4 border-y border-border py-5">
              <Monogram name={s.vendor} />
              <div>
                <p className="font-display text-xl">{s.vendor}</p>
                <VerifiedSeal />
              </div>
            </div>
            <p className="mt-8 max-w-[65ch] text-lg leading-relaxed text-muted-foreground">{s.description}</p>
            <h2 className="mt-12 font-display text-3xl font-medium">What is included</h2>
            <ul className="mt-5 grid gap-3 sm:grid-cols-2">
              {s.included.map((item) => (
                <li key={item} className="flex gap-3"><Check className="mt-0.5 size-5 shrink-0 text-success" strokeWidth={1.75} aria-hidden />{item}</li>
              ))}
            </ul>
            <h2 className="mt-14 font-display text-3xl font-medium">Reviews</h2>
            <ul className="mt-4">
              {s.reviews.map((r) => (
                <li key={r.name} className="border-b border-border py-6">
                  <div className="flex items-center justify-between">
                    <p className="font-semibold">{r.name}</p>
                    <span className="inline-flex items-center gap-1 text-sm text-muted-foreground"><Star className="size-3.5 fill-brass text-brass" strokeWidth={1.5} aria-hidden />{r.rating}.0</span>
                  </div>
                  <p className="mt-1 text-sm text-subtle-foreground">{r.date}</p>
                  <p className="mt-3 max-w-[65ch]">{r.body}</p>
                </li>
              ))}
            </ul>
          </article>
          <aside className="min-w-0 lg:col-span-5" aria-label="Book this service">
            <div className="lg:sticky lg:top-28">
              <DecoFrame>
                <PriceTag paise={s.pricePaise} className="text-4xl" suffix={`for ${formatDuration(s.durationMinutes)}`} />
                <p className="mt-6 mb-3 text-[0.8125rem] font-semibold text-muted-foreground">Day</p>
                <div className="flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Day">
                  {previewDays.map((d) => (
                    <button
                      key={d}
                      type="button"
                      aria-pressed={d === day}
                      onClick={() => setDay(d)}
                      className={cn(
                        'shrink-0 rounded-md border px-3.5 py-2 text-sm font-semibold transition-colors duration-(--duration-fast) ease-(--ease-deco)',
                        d === day ? 'border-brass bg-primary-soft text-foreground' : 'border-border text-muted-foreground hover:border-brass-line',
                      )}
                    >
                      {formatDayLabel(d)}
                    </button>
                  ))}
                </div>
                <SlotPicker className="mt-6" label="Free times" slots={previewSlots} value={slot} onChange={setSlot} />
                <div className="mt-6 grid gap-1.5">
                  <Label htmlFor="preview-address">Address</Label>
                  <NativeSelect id="preview-address" defaultValue="home">
                    <option value="home">Home, 12th Main, HAL 2nd Stage</option>
                    <option value="parents">Parents, 4th Cross, Domlur</option>
                  </NativeSelect>
                </div>
                <Button size="lg" className="mt-6 w-full">{slotLabel ? `Request ${slotLabel}` : 'Choose a time'}</Button>
                <p className="mt-4 text-sm text-muted-foreground">You pay the pro on-site. Free cancellation until 2 hours before the start.</p>
              </DecoFrame>
            </div>
          </aside>
        </div>
      </div>
      <div className="fixed inset-x-0 bottom-0 z-20 flex items-center justify-between gap-4 border-t border-brass-line bg-background px-4 py-3 lg:hidden">
        <PriceTag paise={s.pricePaise} />
        <Button size="lg">{slotLabel ? `Request ${slotLabel}` : 'Choose a time'}</Button>
      </div>
    </>
  )
}
