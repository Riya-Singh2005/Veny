import { QueryClient } from '@tanstack/react-query'
import { AppError } from '@/lib/errors'

/** Errors that will not change on retry (permissions, validation, not found, rules). */
function isPermanent(error: unknown) {
  return error instanceof AppError && error.code !== 'NETWORK' && error.code !== 'INTERNAL'
}

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        refetchOnWindowFocus: false,
        retry: (failureCount, error) => failureCount < 2 && !isPermanent(error),
      },
      mutations: { retry: false },
    },
  })
}
