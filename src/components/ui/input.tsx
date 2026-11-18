import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

export const fieldBase = [
  'w-full rounded-md border border-border bg-surface px-3.5 text-[0.9375rem] text-foreground',
  'placeholder:text-subtle-foreground',
  'transition-[border-color,box-shadow] duration-(--duration-fast) ease-(--ease-deco)',
  'hover:border-brass-line focus-visible:border-ring focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40',
  'disabled:cursor-not-allowed disabled:opacity-50',
  'aria-invalid:border-destructive aria-invalid:ring-destructive/30',
].join(' ')

export function Input({ className, type = 'text', ...props }: ComponentProps<'input'>) {
  return <input data-slot="input" type={type} className={cn(fieldBase, 'h-11', className)} {...props} />
}

export function Textarea({ className, ...props }: ComponentProps<'textarea'>) {
  return <textarea data-slot="textarea" className={cn(fieldBase, 'min-h-28 py-3 leading-relaxed', className)} {...props} />
}

export function NativeSelect({ className, ...props }: ComponentProps<'select'>) {
  return <select data-slot="select" className={cn(fieldBase, 'h-11 appearance-none pr-9', className)} {...props} />
}
