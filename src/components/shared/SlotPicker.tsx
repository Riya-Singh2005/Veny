import { CalendarX } from 'lucide-react'
import { useRef, type KeyboardEvent, type ReactNode } from 'react'
import { Skeleton } from '@/components/ui/skeleton'
import { cn } from '@/lib/utils'

export type Slot = { start: string; label: string; available: boolean }

type SlotPickerProps = {
  slots: Slot[] | undefined
  value: string | null
  onChange: (start: string) => void
  label: string
  isLoading?: boolean
  emptyMessage?: ReactNode
  className?: string
}

/**
 * Signature component: free times shown inside the stepped Deco frame.
 * Implements the ARIA radio-group pattern (arrow keys move, roving tabindex).
 */
export function SlotPicker({ slots, value, onChange, label, isLoading, emptyMessage, className }: SlotPickerProps) {
  const refs = useRef<(HTMLButtonElement | null)[]>([])
  const available = slots?.filter((s) => s.available) ?? []
  const focusIndex = Math.max(0, slots?.findIndex((s) => s.start === value) ?? 0)

  function onKeyDown(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    if (!slots) return
    const step = event.key === 'ArrowRight' || event.key === 'ArrowDown' ? 1 : event.key === 'ArrowLeft' || event.key === 'ArrowUp' ? -1 : 0
    if (!step) return
    event.preventDefault()
    for (let i = 1; i <= slots.length; i++) {
      const next = (index + step * i + slots.length) % slots.length
      const slot = slots[next]
      if (slot?.available) {
        onChange(slot.start)
        refs.current[next]?.focus()
        return
      }
    }
  }

  return (
    <div className={className}>
      <p id="slot-picker-label" className="mb-3 text-[0.8125rem] font-semibold text-muted-foreground">
        {label}
      </p>
      {isLoading ? (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-4" aria-busy="true" aria-label="Loading free times">
          {Array.from({ length: 8 }, (_, i) => (
            <Skeleton key={i} className="h-11" />
          ))}
        </div>
      ) : available.length === 0 ? (
        <div className="flex items-center gap-3 rounded-md border border-dashed border-border px-4 py-5 text-sm text-muted-foreground">
          <CalendarX className="size-5 text-brass" strokeWidth={1.5} aria-hidden />
          {emptyMessage ?? 'No free times on this day. Try another date.'}
        </div>
      ) : (
        <div role="radiogroup" aria-labelledby="slot-picker-label" className="grid grid-cols-3 gap-2 sm:grid-cols-4">
          {slots?.map((slot, index) => {
            const selected = slot.start === value
            return (
              <button
                key={slot.start}
                ref={(el) => {
                  refs.current[index] = el
                }}
                type="button"
                role="radio"
                aria-checked={selected}
                disabled={!slot.available}
                tabIndex={selected || (!value && index === focusIndex) ? 0 : -1}
                onClick={() => onChange(slot.start)}
                onKeyDown={(e) => onKeyDown(e, index)}
                className={cn(
                  'h-11 rounded-md border text-[0.9375rem] font-semibold tabular-nums',
                  'transition-[background-color,border-color,box-shadow] duration-(--duration-fast) ease-(--ease-deco)',
                  slot.available
                    ? 'border-border text-foreground hover:border-brass-line'
                    : 'cursor-not-allowed border-transparent text-subtle-foreground line-through',
                  selected && 'border-brass bg-primary-soft shadow-[inset_0_0_0_1px_var(--brass)]',
                )}
              >
                {slot.label}
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}

/** The stepped Deco frame. Reserved for the booking panel / slot picker, at most once per page. */
export function DecoFrame({ children, className, coreClassName }: { children: ReactNode; className?: string; coreClassName?: string }) {
  return (
    <div className={cn('deco-frame', className)}>
      <div className={cn('deco-core px-6 pb-6 pt-9 sm:px-8 sm:pb-7', coreClassName)}>{children}</div>
    </div>
  )
}
