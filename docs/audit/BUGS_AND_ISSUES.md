# Problem Register (master)

This is the single source of truth for identified problems. Other docs reference these IDs.

**Confidence:**
- **C** = Confirmed from code.
- **P** = Potential risk: depends on runtime, configuration or data.
- **V** = Requires Verification: needs a run, build, lint or audit.

**Severity** reflects actual impact on users, data or security, not code style.

## Critical

| ID | Cat. | Problem | Evidence | Conf. | Impact | Recommended solution | Depends on |
|---|---|---|---|---|---|---|---|
| SEC-01 | Security | Signup and login **return the OTP in the API response**. The client also compares it locally | `Server/src/controllers/authController.js:54,88`; `Client/.../pages/VerifyOTP.jsx:30-35` | C | Email verification and the login second step are meaningless. Anyone can register with or verify any email address, so fake vendors can impersonate real businesses | Generate, store (hashed) and email the OTP only on the server. Never return it. Remove `frontendOtp` | SEC-02 |
| SEC-02 | Security / Arch. | OTP email is sent **from the browser** via EmailJS, so the client must know the OTP | `pages/Login.jsx:37-47`, `pages/Signup.jsx:239-249` | C | Forces SEC-01. The EmailJS public key and template can be abused to send arbitrary-content emails under the Veny template (P) | Use the server-side email provider (Resend is already integrated), with a verified sending domain | — |

## High

| ID | Cat. | Problem | Evidence | Conf. | Impact | Recommended solution | Depends on |
|---|---|---|---|---|---|---|---|
| SEC-03 | Security | Query-parameter filter pass-through with operator rewriting. Raw user input becomes `$regex` | `serviceController.js:182-193` | C | Clients can filter on any field, including inactive or internal ones (`isActive` is forced), and can send expensive or ReDoS regexes. `limit` is uncapped, so `?limit=1000000` dumps the collection | Whitelist filters (`category`, `minPrice`, `maxPrice`, `q`), escape the regex or use a text index, cap `limit` at 50, validate with Zod | SEC-10 |
| SEC-04 | Security | Mass assignment in `updateService`: every body field except 4 is written | `serviceController.js:92,109` | C | An owner can set `images` to arbitrary URLs, `createdAt`, and so on. Integrity risk | Pick explicit allowed fields | SEC-10 |
| BUG-01 | Backend | `errorHandler` takes the status from `res.statusCode`, ignoring `err.statusCode`. No Mongoose error mapping | `middleware/errorMiddleware.js:4` | C | Unknown routes, invalid IDs and validation failures all return **500**. The client shows a generic failure, and monitoring would treat user errors as server errors | `const status = err.statusCode ?? mapMongoose(err) ?? 500` | — |
| BUG-02 | Data | The signup address is silently dropped: `location.address` isn't in the User schema and `User.address` is never set | `models/User.js:42-56`, `pages/Signup.jsx:225-229`, `components/BookingModal.jsx:16` | C | Every booking's address is the literal string `"Home"`, so vendors don't know where to go | Add an address to the schema and pass it from signup and booking. Migrate existing users | Schema approval |
| BUG-03 | Data / UX | Denied geolocation, a timeout or "enter manually" all **silently store hardcoded Noida coordinates** | `pages/Signup.jsx:155-156,160-163,187-193,349` | C | Users outside Noida get wrong locations, which breaks "near me" results and service locations | Geocode the manually entered address. Flag the location source. Never default silently | BUG-02 |
| BUG-04 | Frontend | Explore loads only the first page (10 items) and filters client-side | `pages/AllServices.jsx:149,163-176`; default `limit` in `serviceController.js:197` | C | The marketplace never shows more than the 10 newest services. Search and category filters miss everything else | Use server-side `search`, `category` and pagination, with "load more" | SEC-03 |
| BUG-05 | Full-stack | WhatsApp contact never renders: `vendor.whatsappNumber` is populated from User, but the field is on Service. The URL also double-prefixes `91` | `bookingController.js:79`; `pages/CustomerDashboard.jsx:315,356`; placeholder `AddServiceForm.jsx:215` | C | Customers have no way to contact the vendor after booking | Populate `service.whatsappNumber`. Normalise numbers to E.164 | — |
| BUG-06 | Full-stack | Service edit: removing an existing image has no effect on the server, and uploading any new image **deletes all existing images** | `components/AddServiceForm.jsx:70-72`; `serviceController.js:95-107` | C | Vendors lose images unexpectedly, and the UI contradicts the result | Send `keepImageIds[]`. Destroy only the removed images | — |

## Medium

| ID | Cat. | Problem | Evidence | Conf. | Impact | Recommended solution | Depends on |
|---|---|---|---|---|---|---|---|
| SEC-05 | Security | CORS `origin: '*'` | `Server/src/index.js:24-28` | C | Any site can call the API. The risk is limited because auth uses a Bearer header rather than cookies, but it must change if auth moves to cookies | Allow-list the Vercel domain and localhost via an environment variable | — |
| SEC-06 | Security | The JWT is in localStorage, with a 24h lifetime and no revocation | `pages/VerifyOTP.jsx:40`, `authController.js:9` | C | Any XSS steals the session. Logout doesn't invalidate the token | httpOnly SameSite cookie plus a short access token and a refresh token, or at least a `tokenVersion` | SEC-05 |
| SEC-07 | Security | HTML injection in emails: `options.message` contains user-controlled names and is interpolated raw | `utils/sendEmail.js:26`; messages built in `bookingController.js:51,153` | C | Phishing links or markup can appear in Veny-branded emails | Escape the interpolated values or use a template engine | — |
| SEC-08 | Security | No OTP attempt limit or per-account lockout. The OTP comes from `Math.random`, is stored in plaintext and compared without constant time | `authController.js:33,110`; `User.js:61` | C | A 10⁶ keyspace with only the global IP limit (P). Worse because of SEC-01 | Per-email attempt counter, hashed OTP, `crypto.randomInt`, an auth-specific rate limiter | SEC-01 |
| SEC-09 | Security | IDOR: `markOneRead` updates any notification by ID | `controllers/notificationController.js:70` | C | Low impact (read flag only), but it's a pattern risk | `findOneAndUpdate({_id, user: req.user._id})` | — |
| SEC-10 | Security / BE | No request validation layer. Body types aren't checked, so objects can reach `findOne({email})`. Mongoose validation is the only guard | all controllers | C | Unexpected types produce 500s. Operator payloads are a potential injection vector (P: depends on Mongoose casting and `sanitizeFilter`, V) | Zod schemas plus `validate()` middleware. Consider `mongoose.set('sanitizeFilter', true)` | — |
| SEC-11 | Security | Debug and test routes are exposed in production | `routes/authRoutes.js:15-29` | C | Minor information exposure and API surface | Remove them, or move them to a `/me` endpoint | — |
| SEC-12 | Security | User enumeration through `resend-otp` (404 for an unknown email) and signup ("User already exists") | `authController.js:28,153` | C | Attackers can check which emails are registered | Return generic responses | — |
| SEC-13 | Security | Stack traces are returned unless `NODE_ENV=production` | `errorMiddleware.js:10` | P | Leaks internals if the production environment is misconfigured | Default to hiding stacks | — |
| BE-01 | Backend | Email sending is awaited inside request handlers | `bookingController.js:48`, `:185`; `notificationController.js:14` | C | Booking and status calls are slow or flaky when the email provider is | Queue or fire-and-forget with logging | — |
| BE-02 | Backend | Inconsistent response envelope (`msg`/`message`, `data`/`bookings`/`booking`) | see `architecture/BACKEND_ARCHITECTURE.md` | C | Defensive parsing everywhere in the client and fragile integration | One `respond()` helper | — |
| BE-03 | Backend | No role or date validation on booking: vendors can book, past dates are accepted, duplicates aren't blocked | `bookingController.js:11-44` | C | Data quality and abuse | Validate in a booking service | SEC-10 |
| BE-04 | Backend | Hard delete of a service orphans bookings and reviews | `serviceController.js:145` | C | Dashboards show blank service names | Soft delete, and block deletion while bookings are active | — |
| BE-05 | Backend | The server listens before the database connects. No `uncaughtException` handling or SIGTERM shutdown | `index.js:11,82-90` | C | Errors at startup and on deploy | Await connect, then listen. Add graceful shutdown | — |
| FE-01 | Frontend | Vendor and Customer dashboards duplicate the shell, sidebar, header, `StatCard` and `STATUS_STYLES` (~800 lines in total) | `pages/VendorDashboard.jsx`, `pages/CustomerDashboard.jsx` | C | Every UI change has to be made twice, and they're already drifting apart | A shared `DashboardLayout`, `StatCard` and `StatusBadge` | DS work |
| FE-02 | Frontend | Auth and user state are read from localStorage in 7+ places, with nothing reacting to changes | `axiosClient.js`, `ProtectedRoute.jsx`, `Dashboard.jsx`, `BookingModal.jsx`, `ReviewSection.jsx`, `NotificationBell.jsx`, `ProfileSettings.jsx` | C | Stale UI, an infinite spinner when `user` is missing (`Dashboard.jsx:13`), hard to test | `AuthProvider` plus `GET /me` | — |
| FE-03 | Frontend | The API layer is used inconsistently: half the components call axios directly, and the service modules return different shapes | see `architecture/FRONTEND_ARCHITECTURE.md` | C | Duplicated error handling and inconsistent behaviour | Feature API modules with TanStack Query | BE-02 |
| FE-04 | Frontend | Dashboard sections are `useState`, not routes | `VendorDashboard.jsx:30`, `CustomerDashboard.jsx:29` | C | No deep links. Refresh and Back behave badly | Nested routes | FE-01 |
| UX-01 | UI | Public Navbar ignores auth state; "Join as Vendor" opens the customer role | `components/Navbar.jsx:13-17,46`; `Signup.jsx:121` | C | Logged-in users get lost, and vendor acquisition suffers friction | Auth-aware nav and `/signup?role=vendor` | FE-02 |
| UX-02 | UI / A11y | Labels aren't associated with inputs (0 `htmlFor`), almost no ARIA, modals lack dialog semantics and focus trap, clickable divs | `UI_UX_AUDIT.md` § Accessibility | C | Unusable with screen readers and keyboards | Component library with built-in accessibility | DS work |
| UX-03 | UI / A11y | Low-contrast text (`text-gray-600/700` ×44 on `#020617`) and 122 sub-12px labels | `UI_UX_AUDIT.md` | C (V for exact ratios) | Readability problems | Token-based palette and a 12px minimum | DS work |
| UX-04 | UI | Misleading claims ("Verified Provider", "Secure Transaction", "Avg. 2 Hours", "All Systems Operational") | `ServiceDetail.jsx:162,179,184,229`; `Footer.jsx:75` | C | Trust and legal risk | Remove them, or back them with data | — |
| UX-05 | UI | Password managers are deliberately blocked on login (decoy inputs, `autoComplete="new-password"` on the email field) | `pages/Login.jsx:86-87,100,118` | C | Pushes users toward weaker passwords | Use the correct `autocomplete` tokens | — |
| UX-06 | UI | Guest booking attempt: a toast only, with no redirect to login | `components/BookingModal.jsx:29-34` | C | Lost conversions | Redirect to login with `from`, then resume | — |
| F-01 | Product | Users can't update their location or address after signup | `profileController.js:23` | C | Locations stay wrong forever, which compounds BUG-03 | Location editing in Settings | BUG-02 |
| F-02 | Product | `/nearby` API exists but no UI uses it | `serviceService.js:30` (no callers) | C | The core "local" value isn't delivered | A "Near me" sort or filter in Explore | BUG-03 |

## Low

| ID | Cat. | Problem | Evidence | Conf. | Recommended solution |
|---|---|---|---|---|---|
| FE-05 | Frontend | `Button` ignores the `className` prop callers pass | `components/Button.jsx:3`; `Login.jsx:144` | C | Merge class names, or remove the prop at call sites |
| FE-06 | Frontend | 39 uses of undefined animation utilities (`animate-in`, `fade-in`, `zoom-in-95`, `slide-in-from-top-2`, `animation-delay-2000`) | grep; no animate plugin in `package.json` | C | Add `tw-animate-css`, or remove the classes |
| FE-07 | Frontend | No React error boundary | `App.jsx` | C | Route-level boundary |
| FE-08 | Frontend | Unused dependencies: `@reduxjs/toolkit`, `react-redux`, `nodemailer` (client); `nodemailer` (server); `axios` (root) | grep: 0 imports | C | Remove after approval |
| FE-09 | Frontend | Unused files: `src/App.css` (empty), `src/assets/hero.png`, `react.svg`, `vite.svg`, `public/icons.svg` | grep: 0 references | C | Remove after approval |
| FE-10 | Frontend | `serviceService` wraps calls in no-op try/catch that only rethrows | `services/serviceService.js:11-79` | C | Simplify |
| FE-11 | Frontend | `Map` component shadows the global `Map` | `components/Map.jsx:33` | C | Rename to `LocationMap` |
| FE-12 | Frontend | CSV export doesn't escape commas or quotes | `CustomerDashboard.jsx:72` | C | Quote the fields |
| FE-13 | Frontend | `index.html` title is `veny-frontend`; no meta description | `index.html:7` | C | Proper title and meta |
| FE-14 | Frontend | External texture loaded from `transparenttextures.com` (third-party dependency, privacy) | `Login.jsx:72`, `VerifyOTP.jsx:71` | C | Self-host or remove |
| FE-15 | Frontend | Hero "Scan Galaxy" and dashboard search inputs have no handlers | `AllServices.jsx:46`; `VendorDashboard.jsx:175`; `CustomerDashboard.jsx:172` | C | Wire them up or remove them |
| FE-16 | Frontend | Footer links are all `#` | `components/Footer.jsx:32,46,59` | C | Real pages or removal |
| FE-17 | Frontend | `ProtectedRoute.requiredRole` is never used; `/unauthorized` is unreachable | `App.jsx:46-50` | C | Use it for role routes |
| FE-18 | Frontend | `ServiceDetail` shows "not found" on any error, network errors included | `ServiceDetail.jsx:94-96,112` | C | Distinguish 404 from other errors |
| BE-06 | Backend | `review_new` notification type is never emitted | `models/Notification.js:20`; grep | C | Notify the vendor on a review |
| BE-07 | Backend | Inactive service returns 404 to its owner | `serviceController.js:164` | C | Allow owner access |
| BE-08 | Backend | The earnings chart buckets completed bookings by `createdAt` month name | `VendorDashboard.jsx:111` | C | Use a `completedAt` timestamp |
| BE-09 | Backend | `GET /services/vendor/my-services` has no vendor role check | `serviceRoutes.js:25` | C | `authorize('vendor')` |
| BE-10 | Backend | `select` query parameter is accepted but never applied | `serviceController.js:183` | C | Implement it or drop it |
| BE-11 | Backend | Rate limiter is in-memory and global. Notification polling (30s) consumes the budget | `index.js:38`; `NotificationBell.jsx:40` | C | Separate limiters, a Redis store if scaling out |
| BE-12 | Backend | `morgan('dev')` in all environments; emoji `console.*` logging | `index.js:35` | C | Structured logger |
| BE-13 | Backend | `dotenv.config()` is called twice | `index.js:10`; `db.js:6` | C | Single env loader |
| DB-* | Database | See `architecture/DATABASE_ARCHITECTURE.md` (DB-03…DB-15) | — | C/V | — |
| DOC-01 | Docs | No README, setup guide, `.env.example`, or engines field | repo root | C | Add after approval |
| CODE-01 | Code | Hinglish code comments mixed with English | e.g. `index.js:15,23`; `bookingController.js:46` | C | Standardise on English |

## Requires Verification (static audit could not confirm)

| ID | Item | How to verify |
|---|---|---|
| V-01 | Whether `npm run lint` passes (react-hooks rules likely flag `ReviewSection.jsx:54`, `NotificationBell.jsx:37`) | `npm ci && npm run lint` (needs approval) |
| V-02 | Whether `vite build` succeeds, and the bundle size | `npm run build` |
| V-03 | Dependency vulnerabilities | `npm audit` in both apps |
| V-04 | Mongoose 9 casting of operator objects in `findOne({email: {...}})` and `sanitizeFilter` defaults | Unit test against mongodb-memory-server |
| V-05 | `businessName` `required` function under `findByIdAndUpdate` with `runValidators` | Unit test |
| V-06 | Resend delivery with the `onboarding@resend.dev` sender to non-owner addresses | Staging send |
| V-07 | Production `NODE_ENV`, CORS and environment configuration on Render and Vercel | Dashboard review by the owner |
| V-08 | Existing production data quality (how many users sit on Noida default coordinates, orphaned bookings) | Read-only queries, with approval |
| V-09 | Actual contrast ratios and mobile rendering | Run the app plus axe and Lighthouse |


---

# Reassessment against the target architecture (2026-11-17)

> This section was added after ADR-001 (Supabase, approved) and the recommended Next.js stack ([../planning/DECISIONS.md](../planning/DECISIONS.md)). **The rows above are unchanged.** They still describe the *current* MERN code, and they still apply to the running production app until cutover.

**Outcome legend**

| Code | Meaning |
|---|---|
| **ARCH** | Resolved by the architecture itself, *provided it is built as specified*. Still needs a test |
| **DESIGN** | Resolved only because the target design includes a specific control. That control must be implemented and tested |
| **FIX** | Not solved by the platform. Needs explicit implementation work in the rebuild |
| **N/A** | The code is retired and the issue can't recur in the same form |
| **OPEN** | Still needs verification or a decision |

> **A database migration alone fixes none of the security issues.** Supabase Postgres with RLS disabled, a service-role key in the browser, or a ported custom OTP flow would reproduce SEC-01, SEC-04 and SEC-09 exactly.

## Security

| ID | Outcome | How it is handled in the target | Residual risk / must-do |
|---|---|---|---|
| SEC-01 | **ARCH**, conditional | Supabase Auth owns email confirmation and OTP. Codes are delivered only by email; no app code generates or returns them | **Do not port** `authController` OTP logic, `frontendOtp` or EmailJS. Add a test that sign-up and sign-in responses contain no token or code. There are no legacy accounts (PD-06) |
| SEC-02 | **ARCH** | Auth emails go Supabase Auth → Resend SMTP. Notification emails go through an Edge Function. No email is sent from the browser | Remove `@emailjs/browser`; check the bundle for EmailJS keys |
| SEC-03 | **DESIGN** | The `search_services` RPC uses parameterised, typed arguments, clamps `limit` (≤ 50) and `radius` (≤ 50 km), whitelists `sort`, and uses `websearch_to_tsquery` (no regex). PostgREST filters still exist for direct table reads, but RLS bounds what they can return | Clamp `.range()` sizes in queries. Consider the PostgREST `db-max-rows` setting. Tests for oversized limits |
| SEC-04 | **DESIGN** | Column-level `GRANT UPDATE (…)` on `services`, `profiles` and `vendors`. Counters are writable only by triggers. `vendor_id` is immutable | Tests that a vendor can't update `avg_rating`, `vendor_id` or `deleted_at` |
| SEC-05 | **N/A** | No custom cross-origin API. Supabase project CORS is platform-managed; the app is same-origin with Server Actions | Configure Auth redirect URL allow-lists. Set security headers and CSP in Next.js |
| SEC-06 | **ARCH** | httpOnly cookies via `@supabase/ssr`; refresh-token rotation by Supabase Auth; `signOut` revokes the refresh token | Use `getUser()` on the server, not `getSession()`. Keep XSS hygiene, because Supabase tokens still exist in cookies |
| SEC-07 | **FIX** | Escaped templates in the `send-notification-email` Edge Function | Escape every interpolated value. Unit test with HTML payloads |
| SEC-08 | **ARCH + FIX** | Supabase Auth rate limits and OTP expiry; CAPTCHA on sign-up and sign-in | Enable CAPTCHA and review Auth rate-limit settings (OPEN: current defaults) |
| SEC-09 | **DESIGN** | RLS `user_id = auth.uid()` on `notifications`; update limited to `read_at` | RLS negative test |
| SEC-10 | **DESIGN** | Zod in every Server Action; database check constraints and typed RPC parameters as the last line | Every Server Action validates and authenticates; a lint or code-review checklist |
| SEC-11 | **N/A** | Test routes aren't ported | — |
| SEC-12 | **DESIGN** | Generic UI copy. Supabase Auth email-enumeration protection settings (OPEN: verify options) | Test the sign-up duplicate and reset responses |
| SEC-13 | **N/A / FIX** | No Express stack traces. `error.tsx` boundaries show generic messages | Never return raw Postgres error text to clients; map it through `lib/errors.ts` |
| *new* RLS-01 | **FIX** | A table without RLS is exposed through PostgREST | Migration template plus Security Advisor gate in CI ([../architecture/RLS_AUTHORIZATION.md](../architecture/RLS_AUTHORIZATION.md) §10) |
| *new* RLS-02 | **FIX** | SECURITY DEFINER misuse (mutable `search_path`, missing `auth.uid()` check) | Function checklist plus tests |
| *new* KEY-01 | **FIX** | The service-role key leaks into the client bundle | `server-only` guard; no `NEXT_PUBLIC_` prefix; CI grep |
| *new* VIEW-01 | **FIX** | Views bypass RLS and expose columns | Explicit column lists; tests |

## Bugs

| ID | Outcome | Target handling |
|---|---|---|
| BUG-01 | **FIX** | There's no Express error handler, but the same need returns: `lib/errors.ts` maps Postgres and PostgREST codes to `ActionResult`, with `not-found.tsx` and `error.tsx`. Tests for each code |
| BUG-02 | **DESIGN** | `addresses` table; `create_booking` requires `p_address_id` and snapshots it. Migrated users are prompted to complete their address |
| BUG-03 | **DESIGN + FIX** | `location_source` enum, a geocoding Server Action and no hardcoded default in the UI. Migrated Noida rows are flagged `legacy_default` |
| BUG-04 | **DESIGN** | Server-side `search_services` with pagination; Explore is driven by `searchParams` |
| BUG-05 | **DESIGN** | `vendors.whatsapp_e164` as the single canonical number, normalised to E.164 with no hardcoded prefix; exposed through `get_booking_contact` |
| BUG-06 | **DESIGN** | `service_images` rows with per-image delete and reorder actions |

## Backend

| ID | Outcome | Target handling |
|---|---|---|
| BE-01 | **DESIGN** | Email is sent asynchronously through a trigger, then a queue or webhook, then the Edge Function |
| BE-02 | **DESIGN** | `ActionResult` envelope plus generated database types |
| BE-03 | **DESIGN** | `create_booking` validations: future date, active service, role policy, optional duplicate guard |
| BE-04 | **DESIGN** | Soft delete plus `ON DELETE RESTRICT` |
| BE-05 | **N/A** | No long-running Express process |
| BE-06 | **DESIGN** | `create_review` inserts the `review_new` notification |
| BE-07 | **DESIGN** | RLS owner-read policy on `services` |
| BE-08 | **DESIGN** | `bookings.completed_at`; earnings grouped by it |
| BE-09 | **DESIGN** | RLS plus a role-aware dashboard layout |
| BE-10 | **N/A** | — |
| BE-11 | **ARCH + FIX** | Supabase Auth limits; RPC clamps; optionally Vercel WAF rules. Realtime removes polling |
| BE-12 | **ARCH** | Vercel and Supabase logs; optional Sentry |
| BE-13 | **N/A** | — |

## Frontend & UX

| ID | Outcome | Target handling |
|---|---|---|
| FE-01 | **DESIGN** | A shared `DashboardShell` with role nav configs |
| FE-02 | **ARCH** | Server-side session; no localStorage |
| FE-03 | **DESIGN** | Feature modules (`queries.ts`, `actions.ts`) |
| FE-04 | **ARCH** | App Router nested routes |
| FE-05 | **N/A / FIX** | shadcn `Button` forwards `className`. Keep the rule when customising it |
| FE-06 | **FIX** | Use `tw-animate-css` (the shadcn default in Tailwind v4 setups, Requires Verification) or no animation classes |
| FE-07 | **ARCH** | `error.tsx` / `global-error.tsx` |
| FE-08 | **N/A** | Redux isn't carried over |
| FE-09 | **N/A** | Unused assets aren't carried over |
| FE-10 | **N/A** | — |
| FE-11 | **FIX** | Name the map component `LocationMap` |
| FE-12 | **FIX** | Proper CSV escaping, or a server-generated CSV |
| FE-13 | **ARCH** | `generateMetadata`, a metadata template |
| FE-14 | **FIX** | Don't use the external texture |
| FE-15 | **FIX** | Wire up search or remove it |
| FE-16 | **FIX** | Real footer pages or remove the links |
| FE-17 | **ARCH** | Layout-level role guard |
| FE-18 | **ARCH** | `notFound()` vs `error.tsx` |
| UX-01 | **DESIGN** | Auth-aware header; `?role=vendor` |
| UX-02 | **DESIGN** | shadcn/Radix primitives give dialog semantics and focus management. Labels still have to be written (`<FormLabel>`) |
| UX-03 | **FIX** | Contrast-checked tokens (DESIGN_SYSTEM) |
| UX-04 | **FIX** | Remove the claims, or back them with data (`duration_minutes`, `vendors.status`) |
| UX-05 | **FIX** | Correct `autocomplete` attributes |
| UX-06 | **DESIGN** | Sign-in redirect with `next` |
| F-01 | **DESIGN** | Address management pages |
| F-02 | **DESIGN** | `search_services` with lng and lat; a "Near me" control |
| DOC-01 | **FIX** | README, `.env.example`, `supabase/` docs |
| CODE-01 | **N/A** | New codebase in English |

## Database (from DATABASE_ARCHITECTURE Part A)

| ID | Outcome | Target handling |
|---|---|---|
| DB-01 | **DESIGN** | `addresses` table |
| DB-02 | **DESIGN** | `location_source` |
| DB-03 | **DESIGN** | Soft delete plus `restrict` |
| DB-04 | **DESIGN** | Editable `services.location` and `vendors.base_location` |
| DB-05 | **DESIGN** | A transactional trigger |
| DB-06 | **DESIGN** | `vendor_id` set by the RPC; a consistency trigger |
| DB-07 | **ARCH** | No app-stored OTP |
| DB-08 | **DESIGN** | `business_name not null` on `vendors` |
| DB-09 | **DESIGN** | E.164 check constraints |
| DB-10 | **DESIGN** | Address snapshot from the chosen address |
| DB-11 | **N/A** | — |
| DB-12 | **DESIGN** | `(vendor_id, created_at desc)` index |
| DB-13 | **N/A** | New index set based on actual query patterns |
| DB-14 | **DESIGN** | `pg_cron` retention (pending) |
| DB-15 | **DESIGN** | Check constraint plus an RPC rule |

## Performance (from PERFORMANCE_AUDIT)

| ID | Outcome | Target handling |
|---|---|---|
| PERF-01 | **DESIGN** | Async email |
| PERF-02 | **FIX** | Paginate every list (`range`), with RPC clamps |
| PERF-03 | **DESIGN** | Realtime instead of polling |
| PERF-04 | **DESIGN** | GIN full-text index |
| PERF-05 | **FIX** | `count: 'estimated'` or keyset pagination for deep pages |
| PERF-06 | **DESIGN** | Query-backed indexes |
| PERF-07 | **ARCH** | Route-level code splitting; Leaflet and recharts loaded with `dynamic()` |
| PERF-08 | **DESIGN** | Server-side filtering |
| PERF-09 | **FIX** | The new visual design avoids heavy blur and infinite animation |
| PERF-10 | **ARCH + FIX** | `next/image` with `sizes`; Cloudinary or Supabase transformations |
| PERF-11 | **FIX** | Revoke object URLs in the uploader |
| PERF-12 | **DESIGN** | TanStack Query invalidation and optimistic updates where it's used |
| PERF-13 | **FIX** | — (same as FE-14) |
| PERF-14 | **DESIGN** | Trigger in the same transaction |

## Responsive (RWD-01…RWD-09)
**FIX** for all nine: they are design-implementation items addressed by the Phase 2/3 design system and its responsive test matrix. The platform change doesn't solve any of them.

## Verification items
| ID | Status after re-architecture |
|---|---|
| V-01, V-02 | Apply to the legacy code only. They matter only if the current production app is stabilised before cutover |
| V-03 | Still relevant for the new dependency set; `npm audit` and Dependabot in CI |
| V-04, V-05 | **N/A** to the target (Mongoose is removed). Still relevant to the *current* production app until cutover |
| V-06 | Replaced by: verify Resend domain setup and Supabase Auth SMTP delivery |
| V-07 | Replaced by: review the Vercel and Supabase environment configuration |
| V-08 | **N/A**: there is no production data (PD-06) |
| V-09 | Applies to the new UI (Phase 5) |

## Interim risk: the current production app
**Updated 2026-11-17:** there is no production data (PD-06), so no hotfix of the MERN app (Phase 0b) is planned. If the old deployment is still publicly reachable, anyone can still create accounts with any email (SEC-01). Recommendation: take the old Vercel and Render deployment offline, or put it behind a maintenance page, now rather than at launch (🔐 needs approval: it changes a production deployment).
