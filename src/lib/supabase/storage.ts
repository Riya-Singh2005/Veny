import { supabase } from './client'

/** Public URL for an object in the public `service-images` bucket, or null when no path is set. */
export function serviceImageUrl(path: string | null | undefined): string | null {
  if (!path) return null
  return supabase.storage.from('service-images').getPublicUrl(path).data.publicUrl
}
