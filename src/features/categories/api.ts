import { useQuery } from '@tanstack/react-query'
import { unwrap } from '@/lib/errors'
import { supabase } from '@/lib/supabase/client'

export const categoryKeys = { all: ['categories'] as const }

export function useCategories() {
  return useQuery({
    queryKey: categoryKeys.all,
    queryFn: async () =>
      unwrap(await supabase.from('categories').select('id, slug, name, icon').order('sort_order')),
    staleTime: 10 * 60_000,
  })
}
