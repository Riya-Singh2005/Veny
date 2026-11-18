export const DEFAULT_TIMEZONE = 'Asia/Kolkata'

/** Calendar date (YYYY-MM-DD) in the given timezone, offset by whole days. */
export function dateInTimezone(now: Date, timeZone = DEFAULT_TIMEZONE, addDays = 0): string {
  const shifted = new Date(now.getTime() + addDays * 86_400_000)
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(shifted)
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? ''
  return `${get('year')}-${get('month')}-${get('day')}`
}

/** 24-hour slot label, e.g. "16:30", in the vendor's timezone. */
export function formatSlotTime(iso: string, timeZone = DEFAULT_TIMEZONE): string {
  return new Intl.DateTimeFormat('en-IN', { timeZone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date(iso))
}

/** Day label, e.g. "Wed 18 Nov". */
export function formatDayLabel(isoDate: string, timeZone = DEFAULT_TIMEZONE): string {
  return new Intl.DateTimeFormat('en-IN', { timeZone, weekday: 'short', day: 'numeric', month: 'short' }).format(new Date(`${isoDate}T12:00:00Z`))
}

/** Duration label, e.g. 90 -> "1 h 30 min". */
export function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  if (!h) return `${m} min`
  return m ? `${h} h ${m} min` : `${h} h`
}
