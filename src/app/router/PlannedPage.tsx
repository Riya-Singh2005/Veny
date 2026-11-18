import { Hammer } from 'lucide-react'
import { Link } from 'react-router'
import { EmptyState } from '@/components/shared/marketplace'
import { Button } from '@/components/ui/button'

/** Honest placeholder for routes whose milestone has not shipped yet. Removed as each milestone lands. */
export function PlannedPage({ title, milestone }: { title: string; milestone: string }) {
  return (
    <div className="mx-auto max-w-[90rem] px-4 py-20 sm:px-8 lg:px-16">
      <EmptyState icon={<Hammer strokeWidth={1.5} />} title={`${title} is being built`} action={<Button asChild variant="secondary"><Link to="/">Back to home</Link></Button>}>
        This page arrives in milestone {milestone}. Nothing here is live yet.
      </EmptyState>
    </div>
  )
}
