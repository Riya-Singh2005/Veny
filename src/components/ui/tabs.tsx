import { Tabs as TabsPrimitive } from 'radix-ui'
import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

export const Tabs = TabsPrimitive.Root

export function TabsList({ className, ...props }: ComponentProps<typeof TabsPrimitive.List>) {
  return <TabsPrimitive.List className={cn('flex gap-6 border-b border-border', className)} {...props} />
}

export function TabsTrigger({ className, ...props }: ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      className={cn(
        '-mb-px border-b-2 border-transparent pb-3 text-sm font-semibold text-muted-foreground',
        'transition-colors duration-(--duration-fast) ease-(--ease-deco) hover:text-foreground',
        'data-[state=active]:border-brass data-[state=active]:text-foreground',
        className,
      )}
      {...props}
    />
  )
}

export const TabsContent = TabsPrimitive.Content
