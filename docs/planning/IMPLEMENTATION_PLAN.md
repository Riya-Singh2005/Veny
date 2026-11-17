# Implementation Plan

> **Document structure (revised 2026-11-17)**
> - **Part A: Original MERN backlog.** **Superseded**, kept for reference.
> - **Part B: Backlog for the Supabase + Next.js rebuild.** This is the **current** backlog.
>
> Decision status is tracked in [DECISIONS.md](DECISIONS.md).

# Part A — Superseded (MERN plan)


> **Status: not started.** This is an ordered task backlog derived from [REDESIGN_ROADMAP.md](REDESIGN_ROADMAP.md). Tasks marked 🔐 need explicit approval: schema or data changes, dependency changes, or production configuration.

Conventions for execution:
- One PR per task group.
- Every bug-fix PR includes a regression test.
- Commits follow Conventional Commits.
- Work happens on feature branches off the agreed integration branch (decision pending: `dev` vs `main`).

## Phase 0 — Approvals & decisions (blocking)
- [ ] Answer the product questions in [PRODUCT.md](../product/PRODUCT.md#open-questions-for-the-product-owner).
- [ ] Decide the branch strategy.
- [ ] 🔐 Approve `npm ci`, lint, build and `npm audit` to close V-01..V-03.
- [ ] 🔐 Approve read-only production data inspection (V-08), and say whether there is production data at all.
- [ ] Decide the auth transport: Bearer + `/me`, or httpOnly cookies.

## Phase 1 — Foundation
1. **Tooling**
   1. [ ] Add `.editorconfig`, Prettier config, server ESLint config, root README, `.env.example` for both apps (names only) and `engines` / `.nvmrc` (Node 20.19+ or 22.12+).
   2. [ ] 🔐 Add dev dependencies: vitest, supertest, mongodb-memory-server.
   3. [ ] Split `Server/src/index.js` into `app.js` (exports the app) and `server.js` (connects the database, then listens). Add SIGTERM shutdown.
   4. [ ] Add `config/env.js` validating `MONGO_URI`, `JWT_SECRET` (≥32 chars), `RESEND_API_KEY`, `CLOUDINARY_URL` and `CORS_ORIGINS`.
   5. [ ] CI workflow: lint, then test, then build.
2. **Errors** (BUG-01)
   1. [ ] Add an `AppError` class and fix the `errorHandler` status mapping (CastError → 400, ValidationError → 422, 11000 → 409, Multer `LIMIT_FILE_SIZE` → 413).
   2. [ ] Tests for 404, 400, 422 and 500.
3. **OTP / auth** (SEC-01, 02, 08, 12)
   1. [ ] `auth.service`: `issueOtp(user)` (`crypto.randomInt`, sha256 hash, expiry, attempts = 0, sent via Resend). `verifyOtp(email, code)` (constant-time compare, max 5 attempts, then locked).
   2. [ ] Remove `otp` from the signup and login responses.
   3. [ ] Client: remove EmailJS from `Login.jsx` and `Signup.jsx`, and remove the `frontendOtp` check from `VerifyOTP.jsx`.
   4. [ ] Add a strict rate limiter on `/api/auth/*`.
   5. [ ] Generic responses for resend and signup duplicates.
   6. [ ] 🔐 Remove `@emailjs/browser`.
   7. [ ] Tests: the OTP is never present in any response body; lockout after 5 attempts.
4. **Validation** (SEC-03, 04, 10)
   1. [ ] 🔐 Add `zod`. Add `validate({body, query, params})` middleware.
   2. [ ] Schemas for every auth, service, booking, review and profile route. ObjectId param validation.
   3. [ ] Rewrite the `getAllServices` filter: whitelist `category`, `minPrice`, `maxPrice`, `q`, `sort ∈ {price,-price,createdAt,-createdAt,averageRating}`, `page`, and `limit ≤ 50`. Escape the regex.
   4. [ ] `updateService`: explicit allowed fields.
   5. [ ] Verify V-04, then decide on `mongoose.set('sanitizeFilter', true)`.
5. **Small security fixes**
   1. [ ] `markOneRead` owner filter (SEC-09).
   2. [ ] Remove the test routes (SEC-11).
   3. [ ] Escape values in email HTML (SEC-07).
   4. [ ] CORS allow-list (SEC-05).
   5. [ ] Default to hiding stack traces (SEC-13).

## Phase 2 — Design system
6. [ ] Decide the visual direction (A or B).
7. [ ] Tokens in `index.css` `@theme`, light and dark. Remove raw hex values from new code.
8. [ ] Primitives in `src/components/ui/`: Button → Input/Textarea/Select → Modal/Sheet/ConfirmDialog → Card/Badge/StatusBadge → Alert/EmptyState/Skeleton → Avatar/Rating/Tabs.
9. [ ] `PublicLayout` (auth-aware Navbar, Footer with real links or removed links) and `DashboardLayout`.
10. [ ] 🔐 Optional: Radix primitives; `tw-animate-css`, or remove the animation classes.
11. [ ] Component tests with axe.

## Phase 3 — Core application
12. [ ] 🔐 Add `@tanstack/react-query`, `react-hook-form` and `@hookform/resolvers`.
13. [ ] `AuthProvider` + `GET /api/me`. Remove the direct localStorage reads (FE-02). Error boundary. Lazy routes.
14. [ ] Nested dashboard routes (`/dashboard`, `/dashboard/bookings`, `/dashboard/services`, `/dashboard/settings`) (FE-04).
15. [ ] Auth pages rebuilt (UX-05, `?role=vendor`, resend from the unverified state).
16. [ ] Signup location: geocode the manual address, flag the source, no silent default (BUG-03).
17. [ ] Explore: server-side search, filter and pagination; "Near me" via `/nearby` (BUG-04, F-02).
18. [ ] Service detail: real trust signals only (UX-04); lazy images.
19. [ ] Booking flow: address selection, notes, future-date validation, login redirect and resume (BUG-02 client side, UX-06).
20. [ ] Customer bookings: timeline, WhatsApp fix using `service.whatsappNumber` normalised to E.164 (BUG-05), cancel with reason.
21. [ ] Vendor: merged dashboard widgets (FE-01), bookings inbox, listing editor with `keepImageIds` (BUG-06).
22. [ ] Settings: location and address editing (F-01).
23. [ ] Notifications on TanStack Query with `refetchInterval` and pause when the tab is hidden (PERF-03).

## Phase 4 — Backend & database
24. [ ] Module restructure plus the `respond()` envelope (BE-02). `/api/v1` alias.
25. [ ] 🔐 Schema changes (separate PR, reviewed): User address and `locationSource`, Booking address, `statusHistory`, `cancelReason` and `completedAt`, Service `deletedAt`, OTP token store.
26. [ ] 🔐 Migration scripts with `--dry-run`. Rehearse on a database copy.
27. [ ] Indexes: add the query-backed ones; verify, then 🔐 drop the unused ones.
28. [ ] Async email dispatch (PERF-01).
29. [ ] Pagination on `my-bookings`, reviews and nearby (PERF-02).
30. [ ] 🔐 Replace `multer-storage-cloudinary` and upgrade the Cloudinary SDK.
31. [ ] 🔐 Add pino and pino-http.
32. [ ] Emit `review_new`; let owners read inactive services; earnings by `completedAt`.

## Phase 5 — Testing & quality
33. [ ] API tests for every route (auth, ownership, validation).
34. [ ] 🔐 Add Playwright. E2E happy path plus the cancel path.
35. [ ] Responsive viewport suite. Lighthouse CI budgets.
36. [ ] Security regression tests (OTP leak, IDOR, operator injection).

## Phase 6 — Deployment readiness
37. [ ] 🔐 Production environment review on Render and Vercel; secret rotation.
38. [ ] Health and readiness endpoints. 🔐 Sentry.
39. [ ] Staging environment, PR previews, backup and rollback runbook.
40. [ ] Privacy policy and terms pages (content from the product owner).


---

# Part B — Implementation backlog: Supabase + Next.js rebuild (CURRENT)

> **Status: not started.** Part A above (the MERN backlog) is **superseded** and kept for reference only. Phase 0b and Phase 5 are not needed (PD-06: no production data).
>
> Markers:
> - 🔐 needs explicit approval: external accounts, dependency installs, production systems or data.
> - Every task ships with tests.
> - One PR per task group, using Conventional Commits.

## Phase 0 — Decisions
- [x] ADR-002…ADR-019 approved (2026-11-17).
- [x] PD-01: admin role, yes.
- [x] PD-03 (email + password with confirmation), PD-11 (Pro for production), PD-12 (same repo), PD-13 (admin option b) decided.
- [x] PD-04: vendor self-selection at sign-up, yes. The existing Supabase project is **staging**.
- [ ] Remaining: PD-02, PD-08, PD-09 and PD-14 ([DECISIONS.md](DECISIONS.md)).
- [x] PD-06: no production data, so no migration.
- [ ] 🔐 Take the old MERN deployment (Vercel and Render) offline or into maintenance mode (closes the live SEC-01 exposure).
- [ ] Choose the visual direction (DESIGN_SYSTEM A or B).
- [ ] Choose a geocoding provider (Nominatim within its usage policy, or a commercial API).
- [x] Repository layout decided (PD-12: same repo, `apps/web/` + `supabase/`).

## Phase 0b — NOT NEEDED (PD-06). Kept for reference
- [ ] Remove `otp` from the `signup` and `login` responses; send it through `sendEmail` server-side; remove the client EmailJS send and the `frontendOtp` check.
- [ ] Fix the `errorHandler` status mapping.

## Phase 1 — Supabase foundation
1. [~] The existing Supabase project is **staging** (confirmed 2026-11-17). Supabase CLI 2.107.0 is installed locally and pinned in CI. Staging is linked and the Phase 1 migrations were **applied on 2026-11-17**. Git branches: `dev` → staging, `prod` → production (project not created yet). 🔐 Create the other environment's project; production goes on the Pro plan (PD-11). 🔐 Install the Supabase CLI locally and in CI. Keys live only in git-ignored env files and in the Vercel and Supabase settings, never in docs or commits.
2. [x] `supabase init` (local ports moved to 553xx, to avoid clashing with another local project); enable the `postgis` (and optionally `pg_cron`, `pgmq`) extensions in the first migration.
3. [x] Migration `20261117000100_schema.sql`: the enums and tables in DATABASE_ARCHITECTURE Part B §3–4, with constraints and indexes.
4. [x] Migration `20261117000200_functions.sql` (plus `get_my_vendor` and the `admin_*` RPCs): `handle_new_user`, `guard_profile_role`, `set_updated_at`, `create_booking`, `transition_booking`, `create_review`, `recalc_service_rating`, `search_services`, `soft_delete_service`, `get_booking_contact`, `mark_notifications_read`, `generate_slug`.
5. [x] Migration `20261117000300_rls_grants.sql`: enable RLS on every table, add the policies, column grants and EXECUTE revokes/grants (RLS_AUTHORIZATION §4).
6. [x] Migration `20261117000400_storage.sql`: the `service-images` and `avatars` buckets with their policies. `verification-docs` is deferred until PD-02.
7. [x] `seed.sql`: dev fixtures (categories are in the schema migration, because production needs them too) (two customers, two vendors, **one admin**, services, bookings in every status). Production's first admin is created per PD-14, with the email supplied out-of-band and never committed.
8. [x] `supabase/tests/database/` (92 pgTAP assertions, all passing): pgTAP or Vitest tests covering the full negative-test list in RLS_AUTHORIZATION §9 and every booking transition.
9. [x] CI (`.github/workflows/database.yml`, which has not run on GitHub yet): start the local database, run `db reset`, run the tests, run the advisors, and fail if the generated types differ from the committed ones.
10. [~] Auth configuration. **Local** (`config.toml`): email confirmation required, 8-character passwords with letters and digits, secure password change, TOTP MFA enabled, and a redirect allow-list for `/auth/confirm` and `/auth/reset`. **Staging** is still to do: require email confirmation, 🔐 Resend custom SMTP with a verified domain (SPF, DKIM, DMARC), email templates, redirect URL allow-list, CAPTCHA (🔐 provider account), and leaked-password protection if available.

## Phase 2 — Next.js shell & auth
11. [ ] 🔐 Scaffold `apps/web`: Next.js, TypeScript strict, ESLint, Prettier, Tailwind v4.
12. [ ] `lib/supabase/{server,client,middleware,admin}.ts`. Put `import 'server-only'` in `admin.ts`.
13. [ ] `middleware.ts`: refresh the session and guard `/dashboard/*`.
14. [ ] Route groups and layouts. `DashboardLayout` runs the server-side role guard.
15. [ ] Auth feature: sign-up (Zod schema, role, `?role=vendor`), sign-in, `auth/confirm` route handler, resend, forgot/reset password, sign-out.
16. [ ] `lib/errors.ts` and the `ActionResult` type. `error.tsx`, `not-found.tsx`, `global-error.tsx`.
17. [ ] Security headers and CSP in `next.config`.
18. [ ] 🔐 Add Vitest and Playwright. E2E covers the auth flow against staging, using a test inbox (Mailpit locally via the Supabase CLI).
19. [ ] CI: lint, typecheck, unit tests, build, E2E, and a grep check that the service key is absent from the client bundle.

## Phase 3 — Design system
20. [ ] Tokens (`globals.css` `@theme`) following DESIGN_SYSTEM. 🔐 Run shadcn init and add the components.
21. [ ] Theme the primitives and add the app-specific ones: `StatusBadge`, `Rating`, `EmptyState`, `PriceTag`, `ImageManager`.
22. [ ] `PublicHeader` (auth-aware), `Footer`, `DashboardShell` (sidebar plus mobile tabs).
23. [ ] Accessibility tests with axe for each primitive.

## Phase 4 — Features
24. [ ] **Catalogue:** `/services` driven by `searchParams` and `search_services`; `/services/[slug]` with ISR and `generateMetadata`; JSON-LD; `/categories/[slug]`; `/vendors/[slug]`; `sitemap.ts`; `robots.ts`.
25. [ ] **Vendor listings:** create and edit Server Actions (Zod, column-granted fields); signed-upload image manager (≤ 4 images, reorder, delete); pause; `soft_delete_service`. Revalidate tags on change.
26. [ ] **Addresses:** CRUD with a default address; geocoding Server Action; `location_source` handling; vendor base location and radius.
27. [ ] **Booking:** form → `create_booking`; customer list and detail with a timeline from `booking_status_history`; cancel with a reason via `transition_booking`; contact card via `get_booking_contact` (E.164 WhatsApp link).
28. [ ] **Vendor inbox:** TanStack Query plus a Realtime subscription; transition buttons; earnings chart by `completed_at` (recharts loaded with `dynamic`).
29. [ ] **Reviews:** eligibility query; `create_review`; edit and delete own reviews; public list with pagination.
30. [ ] **Notifications:** panel with TanStack Query + Realtime; `mark_notifications_read`; Edge Function `send-notification-email` (escaped template, `emailed_at` for idempotency, shared-secret auth); 🔐 a database webhook or pgmq trigger.
31. [ ] **Profile & settings:** profile and phone editing; avatar upload; Edge Function `delete-account` (anonymise, then delete).
32. [ ] **Admin (approved; scope PD-13 option b):** `admin_users`, `is_admin()`, separate admin policies (RLS §4.3), `admin_audit_log`, the `admin_set_vendor_status` / `admin_set_review_hidden` / `admin_set_service_hidden` RPCs (database side done in Phase 1), `/dashboard/admin` (vendor queue, suspension, review and listing moderation, read-only bookings), MFA for admins if supported, and RLS tests for the admin role.

## Phase 5 — Data migration: REMOVED (PD-06: no production data). Items kept for reference only
33. [ ] 🔐 Run a read-only `mongodump` and a test restore locally.
34. [ ] Profiling report (MIGRATION §3.2), signed off by the product owner.
35. [ ] `scripts/migration/` ETL in TypeScript: extract from the dump, transform per MIGRATION §5, load through service-role SQL, write `legacy_id_map` and quarantine. Include a `--dry-run` mode.
36. [ ] Validation suite (MIGRATION §7).
37. [ ] Legacy URL redirects (`/service/:mongoId` → `/services/{slug}`).
38. [ ] Two rehearsals on staging, plus a rollback rehearsal.

## Phase 6 — Hardening & launch
39. [ ] Full E2E and responsive matrix; Lighthouse CI budgets.
40. [ ] Security review: RLS audit, Advisor clean, CSP, dependency audit.
41. [ ] 🔐 Production Supabase on a paid plan with backups/PITR; 🔐 Vercel production domain; 🔐 Sentry.
42. [ ] Launch: production Supabase and Vercel domain. 🔐 Take the old MERN deployment offline if that wasn't done in Phase 0.
43. [ ] Hypercare for 14 days. 🔐 Decommission Render. 🔐 Archive the legacy `Client/` and `Server/` (tag first; no deletion without approval).
44. [ ] ~~Cloudinary → Storage image job~~ is moot (PD-07). 🔐 Close the Cloudinary and EmailJS accounts once the old app is offline.
