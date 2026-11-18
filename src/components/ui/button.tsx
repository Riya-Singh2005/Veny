import { cva, type VariantProps } from 'class-variance-authority'
import { Slot } from 'radix-ui'
import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

export const buttonVariants = cva(
  [
    'inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-md font-semibold',
    'transition-[background-color,border-color,color,transform] duration-(--duration-base) ease-(--ease-deco)',
    'active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50',
    "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  ].join(' '),
  {
    variants: {
      variant: {
        primary: 'bg-primary text-primary-foreground hover:bg-primary-hover',
        secondary: 'border border-border bg-surface-raised text-foreground hover:border-brass-line',
        outline: 'border border-brass-line bg-transparent text-foreground hover:bg-surface-raised',
        ghost: 'bg-transparent text-foreground hover:bg-surface-raised',
        // Destructive actions stay quiet (outline) and are placed apart from other actions.
        destructive:
          'border border-destructive/60 bg-transparent text-destructive hover:border-destructive-strong hover:bg-destructive-strong hover:text-primary-foreground',
        link: 'h-auto px-0 text-foreground underline decoration-brass-line hover:decoration-brass',
      },
      size: {
        sm: 'h-9 px-3 text-sm',
        md: 'h-11 px-5 text-[0.9375rem]',
        lg: 'h-12 px-6 text-base',
        icon: 'size-11',
      },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  },
)

export type ButtonProps = ComponentProps<'button'> &
  VariantProps<typeof buttonVariants> & { asChild?: boolean }

export function Button({ className, variant, size, asChild = false, type, ...props }: ButtonProps) {
  const Comp = asChild ? Slot.Root : 'button'
  return (
    <Comp
      data-slot="button"
      type={asChild ? undefined : (type ?? 'button')}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  )
}
