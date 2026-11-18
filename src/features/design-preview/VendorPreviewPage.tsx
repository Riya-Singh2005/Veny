import { CalendarClock, CalendarDays, LayoutGrid, MessageSquareQuote, Sun, UserRound } from 'lucide-react'
import { DashboardLayout, type DashboardNavItem } from '@/app/layouts/DashboardLayout'
import { Monogram, PageHeader, StatusBadge, VerifiedSeal } from '@/components/shared/marketplace'
import { Button } from '@/components/ui/button'
import { cn, formatPrice } from '@/lib/utils'
import { previewDay, previewRequests } from './fixtures'
import { PreviewBanner } from './PreviewBanner'

const nav: DashboardNavItem[] = [
  { to: '/design/vendor', label: 'Today', icon: Sun, end: true },
  { to: '/design/vendor/bookings', label: 'Bookings', icon: CalendarDays },
  { to: '/design/vendor/services', label: 'Services', icon: LayoutGrid },
  { to: '/design/vendor/hours', label: 'Hours', icon: CalendarClock },
  { to: '/design/vendor/reviews', label: 'Reviews', icon: MessageSquareQuote },
]

const nextAction: Partial<Record<(typeof previewDay)[number]['status'], string>> = {
  confirmed: 'Start job',
  in_progress: 'Mark complete',
}

export function VendorPreviewPage() {
  return (
    <>
      <PreviewBanner milestone="M5" />
      <DashboardLayout
        nav={nav}
        area="Pro workspace"
        account={
          <div className="flex items-center gap-3">
            <Monogram name="Ravi" className="size-9 text-base" />
            <div className="hidden min-w-0 lg:block">
              <p className="truncate text-sm font-semibold">Ravi Kumar Electricals</p>
              <VerifiedSeal className="text-xs" />
            </div>
          </div>
        }
      >
        <PageHeader
          title="Thursday, 19 November"
          description={<span><UserRound className="mr-1.5 inline size-4 align-[-2px]" strokeWidth={1.5} aria-hidden />2 requests waiting, 4 jobs on your calendar today.</span>}
          actions={<Button variant="secondary">Block time off</Button>}
        />

        <section aria-labelledby="requests-h" className="mt-12">
          <h2 id="requests-h" className="font-display text-3xl font-medium">New requests</h2>
          <ul className="mt-5 grid gap-4 md:grid-cols-2">
            {previewRequests.map((r) => (
              <li key={r.ref} className="rounded-lg border border-brass-line bg-surface p-6">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-lg font-semibold">{r.customer}</p>
                    <p className="text-sm text-muted-foreground">{r.service}</p>
                  </div>
                  <StatusBadge status="pending" />
                </div>
                <dl className="mt-5 grid grid-cols-3 gap-4 border-t border-border pt-4 text-sm">
                  <div><dt className="text-subtle-foreground">When</dt><dd className="mt-0.5 font-semibold">{r.when}</dd></div>
                  <div><dt className="text-subtle-foreground">Area</dt><dd className="mt-0.5 font-semibold">{r.area}</dd></div>
                  <div><dt className="text-subtle-foreground">Price</dt><dd className="mt-0.5 font-semibold">{formatPrice(r.pricePaise)}</dd></div>
                </dl>
                <div className="mt-6 flex items-center justify-between">
                  <Button>Accept</Button>
                  {/* Destructive action stands apart from the primary one. */}
                  <Button variant="destructive" size="sm">Decline</Button>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section aria-labelledby="day-h" className="mt-14">
          <h2 id="day-h" className="font-display text-3xl font-medium">Your day</h2>
          <ol className="mt-5 grid gap-3 sm:hidden">
            {previewDay.map((job) => (
              <li key={job.time} className={cn('rounded-lg border border-border p-4', job.status === 'in_progress' && 'border-brass-line bg-surface-raised', job.status === 'completed' && 'text-muted-foreground')}>
                <div className="flex items-center justify-between gap-3">
                  <span className="font-display text-2xl tabular-nums">{job.time}</span>
                  <StatusBadge status={job.status} />
                </div>
                <p className="mt-2 font-semibold">{job.customer}</p>
                <p className="text-sm text-muted-foreground">{job.service}, {job.area}</p>
                {nextAction[job.status] ? (
                  <Button className="mt-4 w-full" variant={job.status === 'in_progress' ? 'primary' : 'secondary'}>{nextAction[job.status]}</Button>
                ) : null}
              </li>
            ))}
          </ol>
          <div className="mt-5 hidden overflow-x-auto rounded-lg border border-border sm:block">
            <table className="w-full text-left">
              <caption className="sr-only">Today's jobs in time order</caption>
              <thead className="bg-surface text-xs text-subtle-foreground">
                <tr>
                  <th scope="col" className="px-5 py-3 font-semibold">Time</th>
                  <th scope="col" className="px-5 py-3 font-semibold">Customer</th>
                  <th scope="col" className="hidden px-5 py-3 font-semibold md:table-cell">Service</th>
                  <th scope="col" className="hidden px-5 py-3 font-semibold sm:table-cell">Area</th>
                  <th scope="col" className="px-5 py-3 font-semibold">Status</th>
                  <th scope="col" className="px-5 py-3"><span className="sr-only">Action</span></th>
                </tr>
              </thead>
              <tbody>
                {previewDay.map((job) => (
                  <tr key={job.time} className={cn('border-t border-border transition-colors duration-(--duration-base) ease-(--ease-deco)', job.status === 'completed' && 'text-muted-foreground', job.status === 'in_progress' && 'bg-surface-raised')}>
                    <td className="px-5 py-4 font-display text-2xl tabular-nums">{job.time}</td>
                    <td className="px-5 py-4 font-semibold">{job.customer}</td>
                    <td className="hidden px-5 py-4 md:table-cell">{job.service}</td>
                    <td className="hidden px-5 py-4 sm:table-cell">{job.area}</td>
                    <td className="px-5 py-4"><StatusBadge status={job.status} /></td>
                    <td className="px-5 py-4 text-right">
                      {nextAction[job.status] ? <Button size="sm" variant={job.status === 'in_progress' ? 'primary' : 'secondary'}>{nextAction[job.status]}</Button> : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </DashboardLayout>
    </>
  )
}
