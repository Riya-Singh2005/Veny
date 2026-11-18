import { useQuery } from '@tanstack/react-query'
import { unwrap } from '@/lib/errors'
import { supabase } from '@/lib/supabase/client'

export const serviceKeys = {
  featured: (limit: number) => ['services', 'featured', limit] as const,
  slots: (serviceId: string, date: string) => ['services', serviceId, 'slots', date] as const,
  nextFree: (ids: string[], from: string) => ['services', 'next-free', from, ...ids] as const,
}

/** Newest services from verified vendors (visibility is enforced in the database). */
export function useFeaturedServices(limit = 6) {
  return useQuery({
    queryKey: serviceKeys.featured(limit),
    queryFn: async () => unwrap(await supabase.rpc('search_services', { p_limit: limit, p_sort: 'newest' })),
    staleTime: 60_000,
  })
}

/** Free start times for a service on a vendor-local date (YYYY-MM-DD). */
export function useAvailableSlots(serviceId: string | undefined, date: string) {
  return useQuery({
    queryKey: serviceKeys.slots(serviceId ?? 'none', date),
    queryFn: async () => unwrap(await supabase.rpc('get_available_slots', { p_service_id: serviceId!, p_date: date })),
    enabled: Boolean(serviceId),
    staleTime: 30_000,
  })
}

/**
 * Earliest day with a free slot across the given services (checked in list order, day by day).
 * Returns the service id, the date and that day's free slots, or null when nobody is free on any date.
 */
export function useNextFreeSlot(serviceIds: string[], dates: string[]) {
  return useQuery({
    queryKey: serviceKeys.nextFree(serviceIds, dates[0] ?? ''),
    enabled: serviceIds.length > 0,
    staleTime: 30_000,
    queryFn: async () => {
      for (const date of dates) {
        const results = await Promise.all(
          serviceIds.map(async (id) => ({
            id,
            slots: unwrap(await supabase.rpc('get_available_slots', { p_service_id: id, p_date: date })) ?? [],
          })),
        )
        const hit = results.find((r) => r.slots.length > 0)
        if (hit) return { serviceId: hit.id, date, slots: hit.slots }
      }
      return null
    },
  })
}
