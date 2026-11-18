/**
 * Maps Supabase / PostgREST / Postgres errors to a small set of app error codes.
 * The database raises stable SQLSTATE + HINT codes (docs/architecture/API_DOCUMENTATION.md B3).
 */
export type AppErrorCode =
  | 'VALIDATION'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'INVALID_TRANSITION'
  | 'RULE'
  | 'NETWORK'
  | 'INTERNAL'

export class AppError extends Error {
  readonly code: AppErrorCode
  readonly hint: string | undefined

  constructor(code: AppErrorCode, message: string, hint?: string) {
    super(message)
    this.name = 'AppError'
    this.code = code
    this.hint = hint
  }
}

type PgLikeError = { code?: string; message?: string; hint?: string | null; details?: string | null }

const FALLBACK_MESSAGES: Record<AppErrorCode, string> = {
  VALIDATION: 'Please check the highlighted fields.',
  UNAUTHENTICATED: 'Please sign in to continue.',
  FORBIDDEN: 'You do not have permission to do that.',
  NOT_FOUND: 'We could not find what you were looking for.',
  CONFLICT: 'That conflicts with existing data. Please refresh and try again.',
  INVALID_TRANSITION: 'That action is no longer available for this booking.',
  RULE: 'That action is not allowed.',
  NETWORK: 'Network problem. Check your connection and try again.',
  INTERNAL: 'Something went wrong. Please try again.',
}

function codeFor(pgCode: string | undefined, hint: string | undefined): AppErrorCode {
  if (hint === 'unauthenticated') return 'UNAUTHENTICATED'
  if (hint === 'invalid_transition') return 'INVALID_TRANSITION'
  switch (pgCode) {
    case '42501':
    case 'PGRST301':
      return 'FORBIDDEN'
    case 'P0002':
    case 'PGRST116':
      return 'NOT_FOUND'
    case '23505':
    case '23P01':
    case '23503':
      return 'CONFLICT'
    case '22023':
    case '23514':
    case '22P02':
      return 'VALIDATION'
    case 'P0001':
      return 'RULE'
    default:
      return 'INTERNAL'
  }
}

/** Messages raised by our RPCs are written for end users; generic DB messages are not. */
const USER_FACING_SQLSTATES = new Set(['P0001', 'P0002', '22023', '23P01', '42501'])

export function toAppError(error: unknown): AppError {
  if (error instanceof AppError) return error
  if (error instanceof TypeError && /fetch/i.test(error.message)) {
    return new AppError('NETWORK', FALLBACK_MESSAGES.NETWORK)
  }
  if (error && typeof error === 'object') {
    const e = error as PgLikeError
    const hint = e.hint ?? undefined
    const code = codeFor(e.code, hint)
    const useOwnMessage = e.code !== undefined && USER_FACING_SQLSTATES.has(e.code) && hint !== undefined && !!e.message
    return new AppError(code, useOwnMessage ? (e.message as string) : FALLBACK_MESSAGES[code], hint)
  }
  return new AppError('INTERNAL', FALLBACK_MESSAGES.INTERNAL)
}

/** Unwraps a supabase-js `{ data, error }` result, throwing an AppError on failure. */
export function unwrap<T>(result: { data: T; error: unknown }): T {
  if (result.error) throw toAppError(result.error)
  return result.data
}
