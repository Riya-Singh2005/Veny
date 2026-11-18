import { z } from 'zod'

const envSchema = z.object({
  VITE_SUPABASE_URL: z.url(),
  VITE_SUPABASE_PUBLISHABLE_KEY: z
    .string()
    .min(20)
    // Guard against the most damaging mistake: a secret key must never reach the browser bundle.
    .refine((k) => !k.startsWith('sb_secret_'), 'Secret keys must never be used in the frontend'),
})

export type Env = z.infer<typeof envSchema>

export function parseEnv(raw: Record<string, unknown>): Env {
  const result = envSchema.safeParse(raw)
  if (!result.success) {
    const fields = result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ')
    throw new Error(`Invalid environment configuration (${fields}). Copy .env.example to .env.local.`)
  }
  return result.data
}

export const env: Env = parseEnv(import.meta.env)
