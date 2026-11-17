# Technical Audit (Frontend + Backend)

Architecture descriptions live in `architecture/`. This document evaluates the code against each dimension in the audit brief. IDs refer to [BUGS_AND_ISSUES.md](BUGS_AND_ISSUES.md).

## A. Frontend

| Dimension | Current state | Assessment | IDs |
|---|---|---|---|
| Component architecture | Pages with inline sub-components. A few shared widgets | 🟠 Monolithic pages; two near-duplicate dashboards | FE-01 |
| Reusability | One primitive (`Button`, which drops `className`). Input styles copied everywhere | 🔴 Low | FE-05, UX-02 |
| Page structure | 8 pages; dashboard sections are switched with `useState` | 🟠 | FE-04 |
| Routing | React Router 7 (`BrowserRouter`, declarative `<Routes>`). One protected route. A `Layout` route for public pages | 🟡 Works, but shallow | FE-17 |
| State management | Local state plus localStorage. Redux is installed but unused | 🟠 Unreactive auth state | FE-02, FE-08 |
| API integration | An axios instance with interceptors, but used inconsistently | 🟠 | FE-03 |
| Form handling | Controlled inputs with manual checks | 🟡 Workable, verbose | — |
| Form validation | Client-only `if` checks, one error string per form, no field-level errors | 🟠 | SEC-10 |
| Loading states | Spinners on most async views; buttons have loading states | 🟢 | — |
| Error handling | Toasts plus silent catches. "Not found" shown for any error. No error boundary | 🟠 | FE-07, FE-18 |
| Responsive design | Mobile-first Tailwind, drawer sidebar | 🟡 | RWD-* |
| Accessibility | Labels not associated, minimal ARIA, inaccessible modals | 🔴 | UX-02 |
| UI consistency | Nine radius values, raw hex values, sub-12px type | 🟠 | UX-03 |
| CSS organisation | Tailwind v4 `@theme` tokens, mostly bypassed; utility soup; undefined animation classes | 🟠 | FE-06 |
| Performance | See [PERFORMANCE_AUDIT.md](PERFORMANCE_AUDIT.md) | 🟡 | PERF-* |

Notable code-level issues:
- `Dashboard.jsx:8-11` reads `localStorage.user` in an effect. `JSON.parse(null)` returns `null`, so there's no crash, but the user is left on an infinite spinner.
- `NotificationBell.jsx:24` reads the token on every render. The effect depends on `[token]`, but a string read from localStorage won't change identity between renders, so polling starts once. That's fine, but it can't react to login or logout without a remount.
- `ReviewSection.jsx:54-57` and `NotificationBell.jsx:37-42` call functions defined after the effect. That works through closures, but it violates `exhaustive-deps` (V-01).
- `AddServiceForm.jsx` keeps three parallel image arrays (`images`, `previews`, `existingImages`) and never revokes object URLs, so preview blob URLs leak.
- `ProfileSettings.jsx:30`: `URL.createObjectURL` is never revoked either.
- `BookingModal.jsx:12`: `min={today}` uses a UTC ISO string, so for IST users the minimum time is offset by 5.5h (a confirmed logic issue, low impact).
- `CustomerDashboard.jsx:356`: the hardcoded `91` prefix (BUG-05).

## B. Backend

| Dimension | Current state | Assessment | IDs |
|---|---|---|---|
| App architecture | Single `index.js` bootstrap; app and listen not separated (not testable with Supertest without refactoring) | 🟡 | BE-05 |
| Route organisation | One router per resource, clear | 🟢 | — |
| Controller responsibilities | Validation, data access, side effects and business rules all mixed | 🟠 | BE-01 (arch) |
| Service layer | None (`createNotification` acts as one but lives in a controller) | 🔴 | — |
| Middleware | `protect`, `authorize` and upload are clean and reusable | 🟢 | — |
| Request validation | None | 🔴 | SEC-10 |
| Error handling | Centralised handler exists but maps statuses wrongly | 🔴 | BUG-01 |
| API response consistency | Inconsistent keys and shapes | 🟠 | BE-02 |
| Authentication | JWT with a database lookup per request; OTP broken | 🔴 | SEC-01/06/08 |
| Authorization | Role middleware plus controller ownership checks; a few gaps | 🟡 | SEC-04/09 |
| Business logic | The booking state machine is well defined; review gating is correct | 🟢 | — |
| Logging | `morgan('dev')` plus `console` | 🟠 | BE-12 |
| Rate limiting | Global only | 🟡 | BE-11 |
| Security practices | Helmet, a 50kb body limit, `select:false` on secrets, bcrypt | 🟡 Good basics, critical OTP flaw | see SECURITY_AUDIT |

Unnecessary dependencies: `nodemailer` (server), and `validator` is used for one email check, which would be replaceable by Zod. Tight coupling: `bookingController` → `notificationController` → `sendEmail` → Resend, all synchronous in the request path.

Positive notes worth preserving:
- The booking transition table (`bookingController.js:130-136`) is clear and correct.
- Ownership checks exist on every mutating service, booking and review route.
- Old Cloudinary assets are cleaned up on replacement and delete.
- Reviews require a completed booking and have a unique index, so they're well designed.
- Express 5 async error propagation is available.
- Indexes were considered (a 2dsphere index on the queried collection).

## C. Testing
- There are **no tests** of any kind. The server's `test` script is the npm placeholder (`Server/package.json:8`). The client has no test script. There's no CI.
- Commit history shows bugs fixed one by one ("Bug 3 Fixed", "Bug 5 Fixed", "Bug 6 Fixed") with no regression coverage.

## D. Build & tooling
| Item | State |
|---|---|
| Client build | `vite build` (V-02) |
| Server build | None needed (plain Node) |
| Lint | Client ESLint 9 flat config; server none |
| Formatter | None |
| Type checking | None (`@types/react` is installed but unused without TS) |
| Node version pinning | None (`engines`, `.nvmrc` absent) |
| Env templates | None |


---

## E. Target architecture assessment (Supabase + Next.js, 2026-11-17)

> Sections A–D assess the **current** MERN code and are unchanged. This section assesses the **proposed** target ([../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) Part B). It covers design quality only; nothing has been built.

### E1. Fitness of the target against the audit dimensions
| Dimension | Current (A–D) | Target design | Remaining work / risk |
|---|---|---|---|
| Component architecture | 🟠 Monolithic pages | Feature folders, a shared `DashboardShell`, shadcn primitives | Discipline needed to keep `app/` thin |
| State management | 🟠 localStorage | Server Components + cookie session; TanStack Query only in islands | Avoid duplicate caching (RSC + TanStack) |
| API integration | 🟠 Inconsistent | supabase-js typed client; Server Actions with `ActionResult` | Type generation in CI |
| Validation | 🔴 None | Zod (client and server) + DB check constraints + typed RPC parameters | Every Server Action must validate (review checklist) |
| Error handling | 🔴 Wrong statuses | `lib/errors.ts`, `error.tsx` / `not-found.tsx` | Map every RPC error code |
| Authentication | 🔴 OTP leak | Supabase Auth, email confirmation, cookies | **Must not port the old OTP code** |
| Authorization | 🟡 Ad hoc | RLS + column grants + SECURITY DEFINER RPC | RLS test suite is mandatory |
| Business logic | 🟢 State machine sound | Same rules, now atomic in Postgres functions with a history table | SQL testing skills |
| Data integrity | 🟠 | FKs, checks, soft delete, snapshots | No legacy data to clean (PD-06) |
| Logging / monitoring | 🟠 | Platform logs + Sentry | Configure alerts |
| Performance | 🟡 | RSC, ISR, code splitting, indexes, Realtime, async email | Realtime connection limits per plan |
| SEO | 🔴 Client-rendered only | SSR/ISR, metadata, JSON-LD, sitemap | Content quality, slugs |
| Testing | 🔴 None | Vitest, pgTAP/RLS, Playwright, required in CI | Initial setup effort |
| Deployability | 🟡 Two hosts | Vercel + Supabase, migrations in the repo | Staging parity, secrets hygiene |

### E2. Risks introduced by the target (to be tracked)
| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| T-01 | RLS misconfiguration exposes data through PostgREST | High | Default-deny, Advisor in CI, negative tests ([RLS_AUTHORIZATION.md](../architecture/RLS_AUTHORIZATION.md) §9–10) |
| T-02 | Service-role key leaked to the client | Critical | `server-only`, naming rules, CI bundle scan |
| T-03 | Server Actions treated as private (they are public POST endpoints) | High | Authenticate and validate in every action |
| T-04 | Caching user data in Next.js (cross-user leakage) | High | Authenticated routes are dynamic; no `unstable_cache` with user data |
| T-05 | Supabase free-tier pausing or limits in production | Medium | Paid plan (PD-11) |
| T-06 | Platform coupling (Supabase, Vercel) | Medium | Standard Postgres, migrations in git, portable Next.js |
| T-07 | Rewrite scope and schedule risk | High | Vertical slices (Phase 4), take the legacy app offline (no users depend on it, PD-06) |
| T-08 | ~~Bcrypt hash import not supported~~ | — | **Moot**: no legacy users (PD-06) |
| T-09 | Email deliverability (auth emails are now critical-path) | Medium | Verified domain, DMARC, monitoring |
| T-10 | Edge Function cold starts on the email path | Low | It's asynchronous, so users don't wait |

### E3. Overall
The target design addresses most of the confirmed problems structurally (see the reassessment section in [BUGS_AND_ISSUES.md](BUGS_AND_ISSUES.md)). It also adds a new class of risk: database-level authorization mistakes. The architecture is sound **if, and only if,** the RLS test suite and the "no custom OTP" rule are treated as release gates.
