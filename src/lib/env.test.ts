import { describe, expect, it, vi } from 'vitest'

vi.stubEnv('VITE_SUPABASE_URL', 'http://127.0.0.1:55321')
vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_test_key_123456')

const { parseEnv } = await import('./env')

describe('parseEnv', () => {
  it('accepts a URL and a publishable key', () => {
    const env = parseEnv({
      VITE_SUPABASE_URL: 'https://x.supabase.co',
      VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_abcdefghijklmnop',
    })
    expect(env.VITE_SUPABASE_URL).toBe('https://x.supabase.co')
  })

  it('rejects a secret key in the browser', () => {
    expect(() =>
      parseEnv({ VITE_SUPABASE_URL: 'https://x.supabase.co', VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_secret_abcdefghijklmnopqrst' }),
    ).toThrow(/Secret keys must never/)
  })

  it('rejects missing values with a helpful message', () => {
    expect(() => parseEnv({})).toThrow(/\.env\.example/)
  })
})
