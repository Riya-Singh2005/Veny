# Backend Architecture

> **Document structure (revised 2026-11-17)**
> - **Part A: Current implementation (MERN, audited).** Unchanged from the initial audit.
> - **Part B: Target backend (retire Express; RPC, Server Actions, Edge Functions).** Supabase PostgreSQL is **Approved** (ADR-001). The rest of Part B was **Approved** on 2026-11-17 (ADR-002 to ADR-019).
>
> Decision status is tracked in [../planning/DECISIONS.md](../planning/DECISIONS.md).

# Part A — Current implementation (MERN)


`Server/`: Express 5.2.1, Mongoose 9.6.2, CommonJS, Node ≥ 20.19. Entry point `Server/src/index.js`. Scripts: `start` (node) and `dev` (nodemon). The `test` script is the npm placeholder that exits 1.

## Current implementation

### Folder structure
```
Server/src/
├── index.js                 # app bootstrap, global middleware, route mounting, 404, error handler, listen
├── config/db.js             # mongoose.connect(MONGO_URI); process.exit(1) on failure
├── middleware/
│   ├── authMiddleware.js    # protect (JWT), authorize(...roles)
│   ├── errorMiddleware.js   # errorHandler
│   └── uploadMiddleware.js  # multer + Cloudinary storages (profile 2MB, service 5MB)
├── models/                  # User, Service, Booking, Review, Notification
├── routes/                  # 6 routers
├── controllers/             # 6 controllers (945 lines total)
└── utils/sendEmail.js       # Resend wrapper with inline HTML template
```
The pattern is classic MVC-ish routes → controllers → models. There is **no service layer**, no validators folder and no shared error classes.

### Global middleware order (`index.js`)
1. `helmet({ contentSecurityPolicy: false })` (`:21`)
2. `cors({ origin: '*' , methods, allowedHeaders })` (`:24-28`), plus `app.options(/.*/, cors())` (`:31`)
3. `express.json({ limit: '50kb' })` and `urlencoded` (`:33-34`)
4. `morgan('dev')` (`:35`). Dev format, used in production too.
5. `express-rate-limit`: 100 requests per 15 min per IP, on `/api` (`:38-45`). It uses the in-memory store, so the count is per instance.
6. Routers (`:50-55`)
7. `GET /` health check (`:58`)
8. 404 catch-all, which builds an `Error` with `statusCode = 404` (`:69-73`)
9. `errorHandler` (`:75`)

### Route → controller map
| Mount | Router | Middleware | Controller |
|---|---|---|---|
| `/api/auth` | `routes/authRoutes.js` | — / `protect` / `authorize('vendor')` | `authController` + 2 inline test handlers |
| `/api/services` | `routes/serviceRoutes.js` | Public, then `router.use(protect)`, then `router.use(authorize('vendor'))` | `serviceController` |
| `/api/bookings` | `routes/bookingRoutes.js` | `protect` per route | `bookingController` |
| `/api/profile` | `routes/profileRoutes.js` | `router.use(protect)` + `uploadProfile` | `profileController` |
| `/api/reviews` | `routes/reviewRoutes.js` | Public GET, then `router.use(protect)` | `reviewController` |
| `/api/notifications` | `routes/notificationRoutes.js` | `router.use(protect)` | `notificationController` |

Full endpoint detail: [API_DOCUMENTATION.md](API_DOCUMENTATION.md).

### Authentication
- Passwords are hashed with bcryptjs at cost 10, in the controller (`authController.js:30-31`) rather than in a model hook.
- The JWT is HS256 by default, with payload `{id, role}` and a 24h expiry (`authController.js:7-11`). There is no refresh token, no revocation list and no `tokenVersion`.
- `protect` loads the user from the database on every request (`authMiddleware.js:22`). This is good for freshness, and it means a deleted user is rejected.
- OTP: `Math.random()` 6 digits, 10-minute expiry, stored in **plaintext** in `user.otp`, compared with `String(a) === String(b)` (not constant-time).

### Business logic location
| Rule | Location |
|---|---|
| A vendor can't book their own service | `bookingController.js:22` |
| The booking status state machine | `bookingController.js:118-143` |
| Price snapshot at booking time | `bookingController.js:35` |
| A review requires a completed booking; one per service | `reviewController.js:12-36` and a unique index |
| Average rating recalculation | `models/Review.js:32-50` (static + post hooks) |
| A service's location is copied from the vendor | `serviceController.js:15-37` |
| Notification and email fan-out | `notificationController.createNotification`, imported by `bookingController` |

`createNotification` lives in a controller file but is actually a service helper, so one controller depends on another.

### Error handling
- Every controller uses `try { … } catch (e) { next(e) }`. Express 5 already forwards rejected promises, so these wrappers are redundant but harmless.
- `errorHandler` (`errorMiddleware.js:2-12`):
  - **BUG-01:** the status comes from `res.statusCode`, not `err.statusCode`. Because no controller sets `res.status()` before calling `next(err)`, every forwarded error, **including the 404 handler's**, returns **500**.
  - Mongoose `ValidationError`, `CastError` and duplicate-key `11000` aren't mapped, so all of them return 500 with raw messages.
  - `stack` is included unless `NODE_ENV === 'production'`. If `NODE_ENV` is unset on Render, stack traces leak (Potential risk; Requires Verification).
- Handled errors are returned inline with `res.status(4xx).json({ success:false, msg })`, which bypasses the handler and uses the `msg` key, while the handler uses `message`.

### Response contract (actual)
| Pattern | Where |
|---|---|
| `{ success, msg }` | auth, bookings, profile, reviews, notifications (errors and some successes) |
| `{ success, message }` | services, errorHandler |
| `{ success, data }` | services, profile, reviews, notifications |
| `{ success, booking }`, `{ success, count, bookings }` | bookings |
| `{ success, token, user }` | verify-otp |
| `{ success, unreadCount, data }` | notifications |
| `{ success, count, total, page, totalPages, data }` | GET services |

### Logging
- `morgan('dev')` plus ad-hoc `console.log` and `console.error` with emoji (16 calls). There is no request ID, no log levels and no structured output.

### Integrations
| Integration | Package | Where | Notes |
|---|---|---|---|
| Cloudinary | `cloudinary@1.41.3` (v1 SDK) and `multer-storage-cloudinary@4.0.0` | `uploadMiddleware.js` | Configured from `CLOUDINARY_URL`. Old images are deleted with `uploader.destroy`. multer-storage-cloudinary@4 targets the v1 SDK, which holds back an upgrade to cloudinary v2 |
| Resend | `resend@6.12.4` | `utils/sendEmail.js` | A new client per call. Sender `onboarding@resend.dev` (Resend's shared test sender) |
| Nodemailer | `nodemailer@8.0.3` | **Unused** (verified with grep) | Leftover from earlier SMTP attempts |
| validator | `validator@13` | `models/User.js:17`, the email check | |

## Identified problems
- BE-01: no service layer; controllers are fat.
- BE-02: no request validation (SEC-10).
- BE-03: inconsistent response envelope.
- BE-04: the error handler maps statuses wrongly (BUG-01).
- BE-05: test routes ship to production (`authRoutes.js:15-29`).
- BE-06: the server starts before the database is ready; `uncaughtException` isn't handled; there is no graceful shutdown on SIGTERM, which Render sends on deploy.
- BE-07: the rate limiter uses an in-memory store and one global budget. There is no stricter limiter on auth endpoints.
- BE-08: emails are sent synchronously in the request path. `createNotification` is awaited in `createBooking` and `updateStatus`, so a slow email provider delays the API response.
- BE-09: `getAllServices` builds its filter from raw query params (SEC-03).

## Proposed future (not implemented)
```
Server/src/
├── app.js / server.js          # separate app from listen → testable with Supertest
├── config/env.js               # Zod-validated env
├── lib/ (AppError, asyncHandler?, logger, respond())
├── middleware/ (auth, rbac, validate(schema), rateLimiters, errorHandler)
└── modules/
    ├── auth/ (auth.routes, auth.controller, auth.service, auth.schemas)
    ├── services/ …
    ├── bookings/ (booking.service holds the state machine)
    ├── reviews/
    ├── notifications/ (notification.service + email adapter, async)
    └── users/
```
- Controllers parse the request and call a service, then format the response. Services hold the rules. Models hold the schema.
- One envelope: `{ success: true, data, meta? }` or `{ success: false, error: { code, message, details? } }`.
- Separate stricter rate limits for `/auth/*`.


---

# Part B — Target backend: retire Express (Recommended, ADR-003)

> **Status:** **Approved** (ADR-003, 2026-11-17). The "Proposed future" Express module layout above is **superseded**. Nothing has been implemented yet.

## B1. Why Express is no longer needed
After the move to Supabase:
- Authentication is handled by Supabase Auth.
- Authorization is handled by RLS.
- CRUD runs through PostgREST under RLS.
- Atomic rules run as Postgres RPC.
- Files go to Storage.
- Server-side validation and orchestration run in Next.js Server Actions.
- Secret-key and background work runs in Edge Functions.

Express would only re-implement these layers and add a second host (Render).

**Keep a Node service only if:** heavy integrations appear, such as payment gateway webhooks with complex reconciliation, or long-running jobs beyond Edge Function limits. Even then, Next.js Route Handlers or a queue worker would be considered first.

## B2. Where each current backend responsibility goes

| Current (Express) | Target | Notes |
|---|---|---|
| `authController.signup` | Server Action → `supabase.auth.signUp` + `handle_new_user` trigger | No OTP in the response. Email confirmation goes through Supabase Auth and Resend (SEC-01/02) |
| `authController.login` | Server Action → `signInWithPassword` (PD-03 decided) | Cookie session |
| `authController.verifyOTP` | Supabase Auth `verifyOtp` / confirmation link → `/auth/confirm` route handler | The code never leaves the email |
| `authController.resendOTP` | `supabase.auth.resend()` | Built-in rate limit |
| `protect` middleware | `@supabase/ssr` middleware plus `getUser()` in server code | — |
| `authorize('vendor')` | RLS (`is_vendor()`), plus a layout guard for UX | — |
| `serviceController.getAllServices` / `getNearbyServices` | RPC `search_services(...)` | Validated, clamped, full-text search plus PostGIS |
| `serviceController.getServiceById` | Server Component: `from('services').select(..., service_images(*), vendors(business_name, slug, bio, logo_path, status))` by slug | RLS hides inactive services except from their owner |
| `serviceController.getMyServices` | `from('services').select().eq('vendor_id', uid)` | RLS owner policy |
| `serviceController.createService` / `updateService` | Server Action (Zod) → insert or update `services` under RLS with column grants. Images via signed Storage uploads plus `service_images` rows | Fixes SEC-04 and BUG-06 |
| `serviceController.deleteService` | RPC `soft_delete_service(id)` | Fixes DB-03 |
| `uploadMiddleware` (multer + Cloudinary) | Supabase Storage signed upload URLs, with bucket size and MIME limits | Cloudinary isn't used: there are no legacy images (PD-06) |
| `bookingController.createBooking` | RPC `create_booking(...)` via a Server Action | Address snapshot, future-date check, notification insert |
| `bookingController.getMyBookings` | Server Component query under RLS (participant policy) + `get_booking_contact()` | Pagination via `range()` |
| `bookingController.updateStatus` | RPC `transition_booking(...)` | Row lock, history row, notifications |
| `notificationController.createNotification` | Inserts done inside the RPC functions; an `AFTER INSERT` trigger queues the email | Email leaves the request path (PERF-01) |
| `notificationController.*` (list, read, clear) | Client (TanStack Query) → `from('notifications')` under RLS; RPC `mark_notifications_read` | Realtime subscription replaces polling |
| `profileController.*` | Server Actions → `profiles` / `vendors` updates (column grants); avatar via Storage | — |
| `reviewController.createReview` / `canReview` | RPC `create_review`; eligibility check via a query on the user's completed bookings with no review yet | — |
| `reviewController.getServiceReviews` / `deleteReview` | Select under RLS (public, not hidden); delete under the owner policy | — |
| `sendEmail.js` (Resend, raw HTML) | Edge Function `send-notification-email` with an escaped template (React Email or a plain escaped template) | Fixes SEC-07 |
| `errorMiddleware.js` | `lib/errors.ts`: maps PostgREST and Postgres error codes (`23505` unique, `23503` FK, `23514` check, `P0001` raised by the RPCs, `42501` RLS) to typed results for Server Actions | Fixes BUG-01 |
| `express-rate-limit` | Supabase Auth limits + CAPTCHA; clamps on the RPCs; Vercel firewall / WAF if needed | — |
| `morgan` / `console` | Vercel and Supabase logs; Sentry (optional) | — |
| `helmet` / CORS | Next.js security headers (`next.config` headers, CSP); there's no cross-origin API of our own | SEC-05 goes away |

## B3. Edge Functions (proposed set)
| Function | Trigger | Responsibility |
|---|---|---|
| `send-notification-email` | Database webhook or pgmq on `notifications` insert | Look up the recipient's email (service role), render an escaped template, send via Resend, set `emailed_at`, retry on failure |
| `delete-account` | Authenticated call | Anonymise the profile, delete Storage objects, delete the auth user (see DATABASE_ARCHITECTURE Part B §6) |
| `admin-*` (admin role approved, PD-01) | Authenticated call + `is_admin()` | Verify and suspend vendors, hide reviews and listings, cancel bookings, manage categories (PD-13 option b). Each action writes an audit-log row |

## B4. Postgres layer
Tables, functions, triggers and indexes are defined in [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) Part B. Policies are in [RLS_AUTHORIZATION.md](RLS_AUTHORIZATION.md).

The **business rules preserved from the current code** are:
- The booking state machine.
- No self-booking.
- The price snapshot.
- Reviews only after completion.
- Average-rating recalculation.
- Images limited to 4 per service.
- Business name required for vendors.
- Locations in GeoJSON order (lng, lat).

## B5. Error contract for Server Actions (proposed)
```ts
type ActionResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: { code: 'VALIDATION' | 'UNAUTHENTICATED' | 'FORBIDDEN' | 'NOT_FOUND'
                              | 'CONFLICT' | 'INVALID_TRANSITION' | 'RATE_LIMITED' | 'INTERNAL';
                          message: string; fields?: Record<string, string> } };
```
- One envelope replaces the `msg` / `message` inconsistency (BE-02).
- RPC functions raise errors with stable SQLSTATE codes and the `HINT` / `DETAIL` fields, and the server maps those to error codes.
