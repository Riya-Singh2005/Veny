import { Eye } from 'lucide-react'
import { Link } from 'react-router'

/** Marks screens that render fixture data so nobody mistakes them for live records. */
export function PreviewBanner({ milestone }: { milestone: string }) {
  return (
    <div role="note" className="border-b border-warning/40 bg-warning-soft text-warning">
      <div className="mx-auto flex max-w-[90rem] flex-wrap items-center gap-x-4 gap-y-1 px-4 py-2.5 text-sm font-semibold sm:px-8 lg:px-16">
        <span className="inline-flex items-center gap-2"><Eye className="size-4" strokeWidth={1.75} aria-hidden />Design preview with sample data. Live data arrives in {milestone}.</span>
        <Link to="/design" className="underline underline-offset-4">All previews</Link>
      </div>
    </div>
  )
}
