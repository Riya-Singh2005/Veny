# Veny — project instructions

Veny is a local-services booking marketplace with three roles: **customer**, **vendor** and **admin**.
This repo holds the **new app** (repo root) and the **legacy MERN app** (`Client/`, `Server/`). The legacy app is reference only: don't modify or delete it, and don't copy its patterns.

## Stack (ADR-020, 2026-11-18)
- React 19, TypeScript (strict), Vite 8, React Router 8 (data router, `react-router` + `react-router/dom`).
- Tailwind CSS 4 (`@tailwindcss/vite`) and shadcn/ui (`components.json`; primitives in `src/components/ui`).
- TanStack Query (server state), React Hook Form + Zod (forms and validation), sonner (toasts).
- Supabase:
  - Postgres with PostGIS and RLS;
  - Auth (email + password, confirmation required);
  - Storage, Realtime, Edge Functions (privileged work and email via Resend).
- Vitest + Testing Library (unit), Playwright (E2E, desktop and mobile), pgTAP (database).
- Not allowed: Next.js, Express, Mongo, Redux, EmailJS, Nodemailer, custom JWT auth.

## Commands
| Task | Command |
|---|---|
| Local Supabase stack (Docker) | `supabase start` (ports **553xx**; API 55321, DB 55322, Studio 55323, Mailpit 55324) |
| Rebuild DB from migrations + seed | `supabase db reset` |
| DB tests / lint / advisors | `supabase test db` · `supabase db lint --local --schema public,private` · `supabase db advisors --local` |
| Regenerate DB types | `npm run db:types` (writes `src/types/database.types.ts`; CI fails on drift) |
| Dev server | `npm run dev` (http://127.0.0.1:5173) |
| All checks | `npm run check` (typecheck, lint, unit tests, build) |
| E2E | `npm run test:e2e` (needs the local stack and `.env.local`) |

`.env.local` (git-ignored) holds `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`; see `.env.example`.

## Security rules (non-negotiable)
- The browser uses **only the publishable key**. Secret or service-role keys never go in any `VITE_` variable, the repo, docs or chat. `src/lib/env.ts` rejects `sb_secret_` keys.
- **RLS is the security boundary.** Frontend role checks are UX only.
- Every new table enables RLS **in the migration that creates it**.
- API roles have **no default privileges**: grant table and column privileges explicitly.
- Business writes (bookings, reviews, verification, admin actions) go through `SECURITY DEFINER` RPCs that:
  - set `search_path = ''`;
  - check `auth.uid()`;
  - raise `SQLSTATE` + `HINT` codes.
- Helper and trigger functions live in the unexposed `private` schema.
- Admin rights come only from `public.admin_users`, granted by a direct SQL insert run by the owner. There is no UI or API path to grant admin. Sign-up accepts only `customer` or `vendor`.

## Conventions
- Feature folders: `src/features/<feature>/{api.ts, components/, pages/, schemas.ts}`.
  - `api.ts` holds TanStack Query hooks and query keys.
  - Shared UI goes in `src/components/{ui,shared,forms}`.
- Data access: `unwrap(await supabase…)` from `src/lib/errors.ts`, which throws `AppError` (codes VALIDATION, UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, CONFLICT, INVALID_TRANSITION, RULE, NETWORK, INTERNAL).
  - Show `error.message` to users. RPC messages are written for end users.
- Money is integer paise; format with `formatPrice()`.
- Timestamps are `timestamptz`, and the vendor timezone is in `vendors.timezone`.
- Migrations: `supabase migration new <name>`.
  - Never edit a migration already pushed to staging (`20261117*`, `20261118*`).
  - Add enum values in a separate migration from the code that uses them.
- Path alias: `@/` maps to `src/`. Use type-only imports (`import type`).
- Tests ship with features:
  - pgTAP for every policy and RPC, covering allowed and denied cases;
  - Vitest for logic, forms and guards;
  - Playwright for user journeys.

## Design (premium look is a hard requirement)
- The owner wants a **premium**, non-generic UI. Before any UI work, load the design skills: `impeccable`, `design-taste-frontend` and `high-end-visual-design`. Use `redesign-existing-projects` to audit the old UI, and `brandkit` for identity.
- Motion stays subtle (150–250 ms state transitions). No GSAP or scroll effects.
- WCAG AA contrast. Mobile-first booking flow.
- Design tokens live in `src/styles/globals.css`. Never use raw hex values in components.

## Business rules (decided)
- **PD-02:** vendors must be **verified by an admin** before their services are public or bookable.
- **One booking at a time per vendor**, enforced by the `bookings_no_overlap` exclusion constraint. Slots come from `get_available_slots()`, which uses weekly availability and time off.
- Booking states:
  - `pending` → `confirmed` | `rejected` (vendor) | `cancelled`
  - `confirmed` → `in_progress` → `completed`
- A customer may cancel `pending` at any time, and `confirmed` until **2 h** before the start (`private.customer_cancel_window()`).
- Reviews: one per completed booking.
- Payments are out of scope. The schema is ready to extend later.

## Environments and git
- Branch `dev` deploys to the **staging** Supabase project (linked). Branch `prod` deploys to the production project, which doesn't exist yet.
- **Every `supabase db push` and every `git push` needs the owner's explicit approval.**
- Commits use Conventional Commits.

## Progress (keep updated)
- ✅ Phase 1 DB (2026-11-17): schema, RLS, storage, admin RPCs. 92 pgTAP tests. Applied to staging.
- ✅ M1 (2026-11-18): Vite app scaffold at the root, marketplace migration (verification, availability, slots, overlap, reject, cancel window, favorites). 132 pgTAP, 14 unit and 4 E2E tests. **Not yet pushed to staging.**
- ⏭ M2 design system: the owner picks a visual direction. Then M3 auth, M4 customer, M5 vendor, M6 admin, M7 QA and deploy.
- Plan: `docs/planning/IMPLEMENTATION_PLAN.md` Part C. Decisions: `docs/planning/DECISIONS.md`.
