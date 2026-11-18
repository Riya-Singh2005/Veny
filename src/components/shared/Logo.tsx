import { Link } from 'react-router'
import { cn } from '@/lib/utils'

/** Stepped Deco mark: a ziggurat silhouette, the brand's single ornament. */
export function LogoMark({ className }: { className?: string }) {
  return <span aria-hidden className={cn('deco-mark inline-block size-6 bg-brass', className)} />
}

export function Logo({ className, to = '/' }: { className?: string; to?: string }) {
  return (
    <Link to={to} className={cn('inline-flex items-center gap-3 rounded-sm', className)} aria-label="Veny home">
      <LogoMark />
      <span className="font-display text-[1.65rem] font-medium leading-none tracking-[0.18em]">VENY</span>
    </Link>
  )
}
