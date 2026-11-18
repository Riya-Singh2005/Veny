import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

export function Skeleton({ className, ...props }: ComponentProps<'div'>) {
  return <div data-slot="skeleton" aria-hidden className={cn('animate-pulse rounded-md bg-surface-raised', className)} {...props} />
}

export function Separator({ className, orientation = 'horizontal', ...props }: ComponentProps<'div'> & { orientation?: 'horizontal' | 'vertical' }) {
  return (
    <div
      role="separator"
      aria-orientation={orientation}
      className={cn('shrink-0 bg-border', orientation === 'horizontal' ? 'h-px w-full' : 'h-full w-px', className)}
      {...props}
    />
  )
}
