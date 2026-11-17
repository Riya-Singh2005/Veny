# Technology Recommendations

> **Document structure (revised 2026-11-17)**
> - **Part A: Original recommendations for the MERN stack.** Written during the initial audit.
> - **Part B: Reassessment for Supabase + Next.js.** This is the **current** view, and it overrides Part A wherever they differ.
>
> Decision status is tracked in [DECISIONS.md](DECISIONS.md).

# Part A — Original recommendations (MERN, superseded where Part B differs)


> **Nothing here has been installed, upgraded or removed.** Each item needs approval before adoption.
> Principle: add a tool only when it solves a problem documented in [../audit/BUGS_AND_ISSUES.md](../audit/BUGS_AND_ISSUES.md).

## Keep (current stack is sound)
| Tech | Version | Why keep |
|---|---|---|
| MongoDB + Mongoose | 9.6 | Fits the document model and geo queries; recent major version |
| Express | 5.2 | Current major; native async error propagation |
| React | 19.2 | Current |
| Vite | 8 | Current, fast |
| Tailwind CSS | 4.2 | Already used; the `@theme` tokens suit a design system |
| React Router | 7.15 | Current; supports nested routes and lazy loading |
| axios | 1.16 | Fine as the HTTP layer underneath TanStack Query |
| lucide-react, react-hot-toast, react-leaflet, recharts | — | Adequate for their roles |
| Cloudinary | — | Works. Only the SDK major version is old |
| Resend | 6.x | Already integrated server-side. Should become the **single** email path |

## Remove (pending approval)
| Tech | Reason |
|---|---|
| `@reduxjs/toolkit`, `react-redux` | Unused. Server state belongs in TanStack Query and auth in a Context. A global client store isn't justified |
| `nodemailer` (client and server) | Unused. On the client it's a Node library that was never needed |
| `@emailjs/browser` | Root cause of SEC-01/02. Replaced by server-side Resend |
| Root `axios` | No root code |
| `jwt-decode` | Only needed if the client keeps decoding tokens. Drop it with the `/me` + cookie approach |

## Evaluate / adopt

Each entry covers: (1) what it is, (2) why for Veny, (3) the problem it solves, (4) pros and cons, (5) necessity, (6) migration complexity.

### Zod (server + client validation)
1. A TypeScript-first schema validation library.
2. Veny has no request validation at all.
3. SEC-03, SEC-04 and SEC-10, plus 500 errors on bad input.
4. **Pros:** one schema for server validation, client forms and inferred types; strips unknown keys, which fixes mass assignment. **Cons:** a new dependency; you have to write the schemas.
5. **Necessary.**
6. **Low–Medium.** Add a `validate(schema)` middleware and roll it out route by route.

### TanStack Query (client server-state)
1. A caching, fetching and mutation library.
2. Fetch-in-`useEffect` is repeated in every component, refetches happen manually and error and loading handling is inconsistent.
3. FE-03, PERF-12; it also replaces manual notification polling with `refetchInterval` plus focus refetch.
4. **Pros:** caching, deduplication, retries, optimistic updates, devtools. **Cons:** a learning curve, and one more abstraction.
5. **Strongly recommended.**
6. **Medium.** Migrate one feature at a time.

### React Hook Form (+ `@hookform/resolvers/zod`)
1. A performant forms library using uncontrolled inputs.
2. Signup (400+ lines) and AddServiceForm hand-roll their state and validation.
3. Missing field-level errors, verbose code and inconsistent validation.
4. **Pros:** less code, schema reuse with Zod, accessible error wiring. **Cons:** another API to learn.
5. **Recommended** (optional for trivial forms).
6. **Low.** Adopt it per form during the redesign.

### TypeScript (incremental)
1. A typed superset of JavaScript.
2. The API contract drifts between tiers: `whatsappNumber` is read from the wrong model (BUG-05), and responses mix `msg` and `message`.
3. A whole class of shape and field bugs.
4. **Pros:** catches contract bugs at compile time; better refactoring safety for the redesign. **Cons:** build setup on the server (tsx/tsup), migration effort, and a team skill requirement.
5. **Optional but beneficial.** Recommended for **new** code first (`allowJs`), with Zod-inferred types shared between tiers.
6. **Medium–High** for a full migration; **Low** for an incremental one.

### Zustand
1. A minimal client-state store.
2. Possibly useful for UI state such as the sidebar, filters or the booking draft.
3. Nothing that's broken today. Auth fits a Context, and server data fits TanStack Query.
4. **Pros:** tiny and simple. **Cons:** easy to misuse as a server cache.
5. **Optional / not needed now.** Revisit if cross-page client state appears.
6. Low.

### httpOnly cookie sessions (access + refresh) and `GET /me`
1. Store the session in `HttpOnly; Secure; SameSite` cookies, not localStorage.
2. SEC-06 (XSS token theft), and logout that doesn't revoke the session.
3. Token theft and stale client auth state (FE-02).
4. **Pros:** a token XSS can't read; server-side revocation (token version). **Cons:** cross-site cookies between Vercel and Render need `SameSite=None; Secure` or a shared parent domain, and CSRF protection becomes necessary.
5. **Recommended.** The minimum alternative is to keep Bearer tokens but add `/me`, short expiry and a `tokenVersion`.
6. **Medium**, with deployment and domain implications. **Decision needed.**

### Structured logging: pino (+ pino-http)
1. A fast JSON logger.
2. Logging today is `console` with emoji, plus `morgan('dev')` in production.
3. No request IDs, levels or production diagnostics (BE-12).
4. **Pros:** fast, Render-friendly JSON, redaction of auth headers. **Cons:** less readable in development without `pino-pretty`.
5. **Recommended.**
6. Low.

### Testing: Vitest + Supertest + mongodb-memory-server + React Testing Library + Playwright
1. Unit and integration tests (Vitest), HTTP API tests (Supertest), an in-memory MongoDB, component tests (RTL) and browser end-to-end tests (Playwright).
2. There are currently zero tests, and a redesign without them risks regressions.
3. The bugs this audit found (BUG-01..06) would each have been caught by a simple test.
4. **Pros:** Vitest is Vite-native; mongodb-memory-server needs no external database. **Cons:** setup time; Playwright needs a CI browser cache.
5. **Necessary** (at least Supertest API tests for auth, bookings and services).
6. Low–Medium.

### Error monitoring: Sentry (or similar)
- Front and back. **Recommended** for production readiness. Low complexity.

### Image upload: replace `multer-storage-cloudinary`
- Options: multer `memoryStorage` with `cloudinary.v2.uploader.upload_stream`, or signed direct-to-Cloudinary uploads.
- This unblocks the move to the current Cloudinary SDK and removes an unmaintained dependency (V).
- **Recommended in Phase 4.** Medium complexity.

### `tw-animate-css`
- It would make the 39 existing `animate-in`/`fade-in` classes work. It's only needed if the redesign keeps enter animations; otherwise just remove the classes. **Optional.**

### Not recommended now
| Tech | Why not |
|---|---|
| Next.js / SSR migration | SEO on Explore and detail pages could matter later, but it's a full rewrite. Decide after product questions (V). Vite SPA + prerender is an alternative |
| GraphQL | REST with a consistent contract is enough |
| Microservices | Single small API |
| Redis | Only if horizontal scaling (rate-limit store) or a queue is needed |
| Component kits (MUI, Chakra) | Clash with Tailwind. **Headless primitives** (Radix UI, or shadcn/ui-style copy-in components) are better for accessible modals, dropdowns and popovers. Optional, decide in Phase 2 |


---

# Part B — Reassessment for the Supabase + Next.js direction (2026-11-17)

> Supabase PostgreSQL (ADR-001) and every item marked "Adopt" below (ADR-002 to ADR-019) were **Approved** on 2026-11-17; decision IDs are in [DECISIONS.md](DECISIONS.md). Nothing has been installed.
> Versions: use the latest stable release at implementation time. Check API details (especially `@supabase/ssr`, Next.js caching and the Tailwind v4 + shadcn setup) against current docs then. They are marked Requires Verification.

## B1. Verdict on the proposed stack

| Technology | Verdict | What it does | Why for Veny / problem solved | Disadvantages | Necessary? | Migration complexity |
|---|---|---|---|---|---|---|
| **Next.js (App Router)** | ✅ Adopt (ADR-002) | React framework with server rendering, routing, Server Actions | SEO for public service pages; cookie auth; removes the Express host; route-level code splitting (PERF-07) | RSC and caching learning curve; Vercel-optimised; full rewrite | Strongly recommended | **High** (rewrite of the UI layer) |
| **React** | ✅ Keep | UI library | — | — | Yes | — |
| **TypeScript** | ✅ Adopt, strict, greenfield (ADR-004) | Static typing | Contract bugs (BUG-05, BE-02); generated DB types | Learning curve; build config | Strongly recommended | Low, since the code is new; no conversion of old JS |
| **Supabase PostgreSQL** | ✅ **Approved** | Managed Postgres + PostgREST | Integrity (FKs, checks), relational queries, PostGIS | Vendor coupling (mitigated: plain Postgres) | Yes | High (schema + data migration) |
| **Supabase Auth** | ✅ Adopt (ADR-005) | Hosted auth: email confirm, OTP, reset, sessions | Closes SEC-01/02/06/08/12 when used as designed | Customising email templates and flows is constrained; locks auth into Supabase | Yes | Medium (user import, re-confirmation) |
| **Row Level Security** | ✅ Adopt (mandatory) | Per-row authorization in the DB | Replaces ad-hoc controller checks; fixes SEC-04 and SEC-09 | Easy to misconfigure; must be tested | Yes | Medium |
| **PostGIS** | ✅ Adopt (ADR-008) | Geography types and indexes | "Near me" (F-02), distance sort | An extension to enable | Yes | Low |
| **Postgres functions (RPC)** | ✅ Adopt (ADR-007) | Transactional business logic | Booking state machine, review eligibility, rating counters, validated search | SQL/PLpgSQL skill; harder to unit-test than TS, so pgTAP or Vitest-against-local is needed | Yes | Medium |
| **Supabase Storage** | ✅ Adopt for new uploads | Object storage with RLS-style policies | Replaces multer + multer-storage-cloudinary (outdated dependency) | Image transformations depend on the plan (Requires Verification) | Recommended | Low–Medium |
| **Supabase Realtime** | ✅ Adopt, **limited** (ADR-013) | Postgres change streams over WebSocket | Replaces 30s polling (PERF-03) for notifications and the vendor inbox | Connection limits per plan; RLS on change events adds load | Optional but valuable | Low |
| **Supabase Edge Functions** | ✅ Adopt for specific jobs | Deno serverless functions next to the DB | Email worker, account deletion, admin actions, image migration | Deno runtime; cold starts; separate deploy | Recommended | Low |
| **Tailwind CSS** | ✅ Keep (v4) | Utility CSS | Already used; tokens via `@theme` | — | Yes | Low |
| **shadcn/ui** | ✅ Adopt (ADR-010) | Copy-in accessible components on Radix | UX-02 (dialogs, focus, ARIA); fits Tailwind; the code is owned locally | You maintain the copies; must be re-themed to DESIGN_SYSTEM tokens | Recommended | Low |
| **TanStack Query** | ⚠️ Adopt **only for client islands** (ADR-012) | Client cache, mutations, invalidation | Optimistic updates, Realtime-driven refresh, infinite Explore | Duplicates RSC caching if overused | Optional | Low |
| **React Hook Form** | ✅ Adopt | Form state | Signup and service forms; field errors | — | Recommended | Low |
| **Zod** | ✅ Adopt | Runtime schemas | SEC-10; shared between form and Server Action | — | Yes | Low |
| **Resend** | ✅ Keep (single provider) | Transactional email API | Already integrated server-side; Supabase Auth custom SMTP; Edge Function emails | Needs a verified domain (today's `onboarding@resend.dev` is a test sender) | Yes | Low |
| **Vitest** | ✅ Adopt | Unit and integration tests | Zero tests today | — | Yes | Low |
| **Playwright** | ✅ Adopt | E2E browser tests | Core flows, responsive matrix | CI time | Yes | Low–Medium |
| **Vercel** | ✅ Adopt (ADR-015) | Next.js hosting | Already hosts the SPA; native Next.js support | Cost at scale; platform coupling | Recommended | Low |

## B2. Additions the proposal didn't list (recommended)
| Item | Reason | Necessity |
|---|---|---|
| `@supabase/ssr` + `@supabase/supabase-js` | Cookie-based server and browser clients | Required |
| Supabase CLI (local stack, migrations, `gen types`, `test db`) | Reproducible schema; RLS tests in CI | Required |
| pgTAP (via `supabase test db`) or Vitest with per-role JWTs | Testing RLS and RPC (ADR-014) | Required |
| CAPTCHA (Cloudflare Turnstile or hCaptcha, both Supabase Auth integrations) | Bot sign-ups and OTP abuse (SEC-08) | Recommended |
| `next-themes` | Light and dark modes (DESIGN_SYSTEM) | Optional |
| Sonner (shadcn toast) | Replaces react-hot-toast | Optional |
| `react-leaflet` (keep), loaded via `dynamic(..., { ssr:false })` | Maps; no change in provider | Keep |
| React Email (optional) | Typed, escaped email templates in the Edge Function | Optional |
| Sentry | Error monitoring, front and back | Recommended for production |
| `pgmq` (Supabase Queues) | Retryable email jobs | Optional (a DB webhook is the simpler alternative) |
| `libphonenumber-js` | E.164 normalisation (BUG-05) | Recommended |

## B3. Items from Part A that change
| Part A recommendation | Status now |
|---|---|
| Zod, RHF, Vitest, Playwright, Sentry | Unchanged; still recommended |
| TanStack Query | Narrowed to client islands |
| TypeScript (incremental) | Becomes **greenfield strict** |
| httpOnly cookie auth | Provided by `@supabase/ssr` |
| pino logging | **Dropped**: no Node server. Use platform logs and Sentry |
| Supertest, mongodb-memory-server | **Dropped**: no Express or Mongo. Replaced by the Supabase local stack and RLS tests |
| Replace multer-storage-cloudinary | Superseded: Supabase Storage |
| Keep Express / Mongoose / axios | **Retire** once the new app launches |
| Remove EmailJS, Redux, nodemailer | Unchanged: none of them are carried over |

## B4. Deferred / rejected for now
- **Prisma or Drizzle:** deferred. Using the service-role connection would bypass RLS, and the typed supabase-js client plus RPC is enough.
- **Zustand:** deferred, because there's no global client state.
- **tRPC:** rejected. Server Actions plus generated types cover the need.
- **A separate Express or Node API:** rejected unless large non-Supabase integrations appear (DECISIONS: Rejected/Deferred).
