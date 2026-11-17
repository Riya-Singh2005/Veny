# Architecture Decision Log

This is the single place to see what is **decided** and what is **still open**. Other documents link here instead of restating decision status.

Status values:
- **Approved**: the product owner has decided.
- **Recommended**: the architect's recommendation, awaiting approval. None outstanding since 2026-11-17.
- **Resolved / Moot**: a pending question that has been answered, or no longer applies.
- **Pending**: needs a product-owner decision. Options are listed.
- **Rejected / Deferred**: not adopted now.

> **Update 2026-11-17:** the product owner accepted the recommendations for PD-03, PD-11, PD-12 and PD-13. A Supabase project has been created by the product owner; its URL and publishable key are held outside the docs (see ARCHITECTURE.md B4). The product owner also approved ADR-002 to ADR-019, confirmed there is **no production data** (PD-06) and requested an **admin role** (PD-01).
>
> Nothing in this log has been implemented. No package has been installed, no Supabase project has been created and no database has been touched.

---

## Approved

### ADR-001 — Replace MongoDB with Supabase (PostgreSQL)
- **Status:** Approved (2026-11-17, product owner).
- **Context:** The MongoDB data model shows integrity problems: dropped addresses, orphaned bookings, a denormalised rating with no enforcement, and no referential integrity (`docs/architecture/DATABASE_ARCHITECTURE.md` Part A). Authorization is ad hoc in controllers.
- **Consequences:**
  - A relational schema with foreign keys and check constraints.
  - Row Level Security as the authorization backbone.
  - PostGIS for geographic search.
  - A data migration from MongoDB is required (`MONGODB_TO_SUPABASE_MIGRATION.md`).
  - Mongoose and the Express data layer will be retired.

---

## Approved 2026-11-17 — ADR-002 to ADR-019

All of these were approved by the product owner on 2026-11-17. ADR-019 is approved but has no effect now, because PD-06 means there are no legacy images (see below).

| ID | Decision | Rationale (summary) | Detail |
|---|---|---|---|
| ADR-002 | **Next.js (App Router) replaces the React + Vite SPA** | SEO for public service and category pages, server-side cookie auth, and no separate API host | `architecture/FRONTEND_ARCHITECTURE.md` Part B |
| ADR-003 | **Retire the Express API.** Split its responsibilities between Postgres functions (RPC), Next.js Server Actions / Route Handlers and Supabase Edge Functions | Every current endpoint maps cleanly onto those three, and keeping Express would duplicate auth and add a host | `architecture/BACKEND_ARCHITECTURE.md` Part B |
| ADR-004 | **TypeScript (strict) for all new code.** No incremental conversion of the old JS, which is being replaced | Contract bugs such as BUG-05 are type errors. Supabase can generate database types | `TECHNOLOGY_RECOMMENDATIONS.md` |
| ADR-005 | **Supabase Auth** with server-side email confirmation and httpOnly cookie sessions via `@supabase/ssr`. The custom OTP code is **not** ported | Closes SEC-01, SEC-02, SEC-06 and SEC-08 by design | `architecture/RLS_AUTHORIZATION.md` §2 |
| ADR-006 | **Role model:** `profiles.role ∈ {customer, vendor}`, set once by a trigger at signup. Users can't update it. Admin rights live in a separate `admin_users` table writable only by the service role | Prevents privilege self-assignment | `RLS_AUTHORIZATION.md` §3 |
| ADR-007 | **Business rules in Postgres functions**: booking creation, status transitions, review creation and rating recalculation, each in one transaction | Atomic, close to the data, enforced for every client | `DATABASE_ARCHITECTURE.md` Part B §5 |
| ADR-008 | **PostGIS `geography(Point,4326)`** with GiST indexes for "near me" | Correct distances, indexable | `DATABASE_ARCHITECTURE.md` Part B |
| ADR-009 | **Email:** Resend as the custom SMTP for Supabase Auth emails, and a Supabase Edge Function for notification emails triggered from the `notifications` table | One provider, server-side only. Escaping happens in one place (SEC-07) | `BACKEND_ARCHITECTURE.md` Part B |
| ADR-010 | **UI:** Tailwind CSS + shadcn/ui (Radix-based, copied into the repo) implementing `design/DESIGN_SYSTEM.md` | Accessible primitives (UX-02), the team owns the code, fits Tailwind | `TECHNOLOGY_RECOMMENDATIONS.md` |
| ADR-011 | **Forms:** React Hook Form + Zod. The same Zod schemas validate inside Server Actions | SEC-10, field-level errors | — |
| ADR-012 | **Data fetching:** Server Components for reads. TanStack Query **only** for client-interactive dashboard views and notifications | Avoids two competing caches. See the reasoning in `FRONTEND_ARCHITECTURE.md` Part B §4 | — |
| ADR-013 | **Realtime:** only for notifications and the vendor's incoming bookings. Everything else is request/response | Limits connection cost and complexity | — |
| ADR-014 | **Testing:** Vitest for unit tests, RLS and RPC tests (Vitest or pgTAP) against the local Supabase CLI stack, and Playwright for end-to-end tests | RLS is now the security boundary, so it has to be tested | `REDESIGN_ROADMAP.md` |
| ADR-015 | **Hosting:** Vercel (Next.js) and Supabase (managed). Render is retired once the new app launches | One fewer host | — |
| ADR-016 | **Money:** integer minor units (`price_paise`), with a `currency` column defaulting to `INR` | Avoids float rounding. Stays future-proof if payments arrive | — |
| ADR-017 | **One review per booking** (unique `booking_id`) instead of one per service per customer | Ties each review to proof of service. Repeat customers can review each visit. This intentionally changes current behaviour | `DATABASE_ARCHITECTURE.md` Part B |
| ADR-018 | **Soft delete for services** (`deleted_at`). Bookings reference services with `ON DELETE RESTRICT` | Fixes DB-03 orphaning | — |
| ADR-019 | **Migration cutover keeps the Cloudinary URLs** (`storage_provider = 'cloudinary'`). Copying to Supabase Storage is a later, separate job | Approved, but **has no effect** because PD-06 means there are no legacy images to keep. All images go to Supabase Storage, and Cloudinary isn't used | `MONGODB_TO_SUPABASE_MIGRATION.md` §6 |

---

## Resolved 2026-11-17

| ID | Question | Answer | Consequences |
|---|---|---|---|
| PD-01 | Admin / moderation role at launch? | **Yes** | `admin_users` and `is_admin()` become **required** rather than conditional. The admin console (roadmap 4.9) is in scope. Admin powers are defined by PD-13 |
| PD-06 | Is there live production data? | **No** | No MongoDB → Postgres ETL: **migration Phase 5 is removed**. Start fresh with seeded categories. `migration.legacy_id_map`, legacy URL redirects and the Cloudinary image provider aren't needed. The optional Phase 0b hotfix isn't needed. PD-05, PD-07 and PD-10 become moot |
| PD-05 | Re-confirm existing users? | **Moot**: there are no existing users | — |
| PD-07 | Cloudinary long-term? | **Moot**: there are no legacy images. Use Supabase Storage only | Drop `provider`, `external_url` and `external_public_id` from `service_images` |
| PD-10 | Migrate notification history? | **Moot** | — |
| PD-03 | Auth method? | **Email + password, with email confirmation required** (recommendation accepted). Passwordless OTP or magic link may be added later | Sign-up and sign-in Server Actions use `signUp` / `signInWithPassword`. Supabase Auth setting: email confirmation on |
| PD-11 | Supabase plan? | **Pro for production** (recommendation accepted). Free is acceptable for development and staging | Production project on Pro (backups, no pausing). Plan terms: Requires Verification at purchase |
| PD-12 | Repo layout? | **Same repo**, new `apps/web/` and `supabase/` folders. Legacy `Client/` and `Server/` are kept until launch, then archived (🔐) | Phase 1 scaffolds `supabase/` at the repo root |
| PD-13 | What can admins do? | **Option (b)** (recommendation accepted): verify and suspend vendors, hide reviews and listings, view all bookings, cancel bookings from any non-terminal state, and manage categories. No role changes or user impersonation in v1 | RLS admin policies and admin RPCs limited to these actions, each written to `admin_audit_log` |
| PD-04 | Can users self-select the vendor role? | **Yes** (recommendation accepted). New vendors start `unverified` | Implemented in `private.handle_new_user()`: only `customer` or `vendor` are accepted, and anything else becomes customer |
| ENV | Is the existing Supabase project staging or production? | **Staging** (confirmed 2026-11-17) | Production will be a separate project on the Pro plan (PD-11). Nothing has been applied to staging yet |

## Pending (product-owner decisions)

| ID | Question | Options | Recommendation | Blocks |
|---|---|---|---|---|
| PD-02 | Is **vendor verification** required before a vendor's listings go public? | (a) required · (b) a badge only · (c) none | (b) at launch, (a) later | `vendor_verifications` table |
| PD-08 | **Market scope**: India-only? | INR / +91 defaults vs multi-currency and region | India-first, with a `currency` column and E.164 phone numbers | Validation rules |
| PD-09 | **Payments** | Out of scope / later | Out of scope for this rebuild | Booking schema extension |
| PD-14 | **How is the first admin created?** | (a) a SQL migration that inserts a given email's profile into `admin_users` · (b) a one-off service-role script | (b) a one-off SQL run against the target project by the product owner, using an email that is never committed. Local dev already seeds `admin@veny.test` | First staging or production admin |

---

## Rejected / Deferred

| Item | Status | Reason |
|---|---|---|
| Keeping Express alongside Supabase | Rejected unless needs grow | Duplicate auth layer; nothing that Next.js, RPC and Edge Functions can't cover |
| Redux / Zustand | Deferred | No cross-page client state that justifies a store |
| Prisma or Drizzle ORM | Deferred | The supabase-js typed client plus RPC is enough. Add Drizzle only if complex server-side SQL grows. It would also bypass RLS when using the service connection |
| GraphQL (pg_graphql) | Deferred | REST/RPC is enough |
| Payments | Deferred (PD-09) | — |
| Microservices | Rejected | Wrong scale |
