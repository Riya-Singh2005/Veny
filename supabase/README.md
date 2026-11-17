# Veny — Supabase database

The Phase 1 database for the Next.js rebuild: schema, functions, RLS, Storage, seed and tests.
The design is in [`docs/architecture/DATABASE_ARCHITECTURE.md`](../docs/architecture/DATABASE_ARCHITECTURE.md) (Part B, see §0 for how the implementation differs from it) and [`docs/architecture/RLS_AUTHORIZATION.md`](../docs/architecture/RLS_AUTHORIZATION.md).

## Layout

| Path | Contents |
|---|---|
| `migrations/20261117000100_schema.sql` | PostGIS, enums, tables, constraints, indexes. RLS is enabled at creation. Categories (production reference data) |
| `migrations/20261117000200_functions.sql` | Triggers, RPCs, admin RPCs. Helpers live in the unexposed `private` schema |
| `migrations/20261117000300_rls_grants.sql` | Privilege reset, table and column grants, RLS policies, Realtime publication |
| `migrations/20261117000400_storage.sql` | `service-images` and `avatars` buckets and their policies |
| `seed.sql` | **Local dev fixtures only** (never pushed to a remote project) |
| `tests/database/*.test.sql` | pgTAP tests: RLS negatives, booking transitions, reviews and ratings, admin |
| `types/database.types.ts` | Generated TypeScript types. CI fails if they drift |

## Local development

Needs Docker Desktop and Supabase CLI 2.107.0 (the version pinned in CI). The ports are **553xx** (API 55321, DB 55322, Studio 55323, Mailpit 55324), not the CLI defaults, so they don't clash with other local projects.

```sh
supabase start            # first run pulls images; applies migrations + seed
supabase db reset         # rebuild from migrations + seed
supabase test db          # pgTAP suite
supabase db lint --local --schema public,private
supabase db advisors --local --type all
supabase gen types typescript --local --schema public > supabase/types/database.types.ts
```

Seed accounts use the password `VenyDev2026` and exist **only on the local stack**: `customer.a@veny.test`, `customer.b@veny.test`, `vendor.a@veny.test`, `vendor.b@veny.test`, `admin@veny.test`. Confirmation emails go to Mailpit at http://127.0.0.1:55324.

## Writing a migration

- Create it with `supabase migration new <name>`. Never edit a migration that has been applied to a remote project.
- Enable RLS on every new table **in the same migration** that creates it.
- API roles get **no privileges by default** (the default privileges are revoked). Grant `select`, `insert (cols)` and `update (cols)` explicitly, and add policies.
- `SECURITY DEFINER` functions: `set search_path = ''`, fully qualified names, check `auth.uid()`, never take the acting user's ID as a parameter, and grant `execute` only to the roles that need it.
- Raise errors with a stable `SQLSTATE` and a `HINT` code (see API_DOCUMENTATION B3).
- Add pgTAP tests for both the allowed and the denied cases.

## Remote projects

- The existing project is **staging** and is linked. Migrations up to `20261117000400` were applied on 2026-11-17. Future pushes still need the product owner's approval. Branch `dev` maps to staging, and `prod` will map to the production project.
- Keys and the database password are never committed or pasted into chat. Run `supabase login` and `supabase link` yourself.
- The first admin on a remote project is created with a one-off SQL insert into `public.admin_users`, run by the product owner (PD-14). There is no UI or API path that grants admin rights.
