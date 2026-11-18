import { useCategories } from './api'

/**
 * Milestone M1 placeholder: proves the app talks to Supabase under RLS (anon role).
 * Replaced by the real home page in M4.
 */
export function FoundationPage() {
  const { data, isPending, error } = useCategories()
  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <h1 className="text-3xl font-semibold tracking-tight">Veny</h1>
      <p className="mt-2 text-muted-foreground">Foundation build. The design system arrives in the next milestone.</p>
      <section aria-labelledby="categories-heading" className="mt-10">
        <h2 id="categories-heading" className="text-sm font-medium uppercase tracking-wide text-muted-foreground">
          Categories
        </h2>
        {isPending && <p className="mt-4">Loading…</p>}
        {error && (
          <p role="alert" className="mt-4">
            {error.message}
          </p>
        )}
        {data && (
          <ul className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3" data-testid="category-list">
            {data.map((c) => (
              <li key={c.id} className="rounded-lg border px-4 py-3">
                {c.name}
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  )
}
