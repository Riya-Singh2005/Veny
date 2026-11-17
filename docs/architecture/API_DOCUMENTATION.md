# API Documentation (as implemented)

> **Document structure (revised 2026-11-17)**
> - **Part A: Current implementation (MERN, audited).** Unchanged from the initial audit.
> - **Part B: Target API surface (Supabase + Server Actions).** Supabase PostgreSQL is **Approved** (ADR-001). The rest of Part B was **Approved** on 2026-11-17 (ADR-002 to ADR-019).
>
> Decision status is tracked in [../planning/DECISIONS.md](../planning/DECISIONS.md).

# Part A — Current implementation (MERN)


- Base path: `/api`. The client uses `VITE_API_BASE_URL`, which must already include `/api`.
- Auth: header `Authorization: Bearer <JWT>` where 🔒 is shown. The JWT is obtained only from `POST /auth/verify-otp`.
- All endpoints share one rate limit of 100 requests per 15 minutes per IP (`Server/src/index.js:38-45`).

> ⚠️ Because of BUG-01, **any error passed to `next()` returns HTTP 500**, whatever its intended status. This covers unknown routes, invalid ObjectIds and Mongoose validation failures. Errors returned inline by controllers use the correct 4xx codes.

Error response shapes:
- inline: `{ "success": false, "msg": "..." }`, or `"message"` in the service routes
- handler: `{ "success": false, "message": "...", "stack": "..." | null }`

---

## Health
### `GET /`
`200 { success, message: "Veny API is running in Orbit... 🚀", version: "1.0.0" }`

---

## Auth (`routes/authRoutes.js`, `controllers/authController.js`)

### `POST /api/auth/signup`
Body:
```json
{ "name": "string", "email": "string", "password": "string", "role": "customer|vendor",
  "businessName": "string (vendor)", "location": { "type": "Point", "coordinates": [lng, lat], "address": "string (dropped)" } }
```
- 400 `Location is required` · 400 `Business name is required for vendors` · 400 `User already exists`
- 201 `{ success, msg, otp }`. ⚠️ **SEC-01: returns the OTP.**
- Mongoose validation errors (name length, email format, password < 6) return 500 (BUG-01).

### `POST /api/auth/login`
Body `{ email, password }`.
- 400 `Invalid credentials` · 403 `Please verify your email first.`
- 200 `{ success, msg, otp, name }`. ⚠️ **SEC-01.** A new OTP is written to the user.

### `POST /api/auth/verify-otp`
Body `{ email, otp }`.
- 400 `OTP not found or already used.` · 400 `OTP has expired…` · 400 `Invalid OTP.`
- 200 `{ success, msg, token, user: { id, name, role, email, location } }`. It sets `isVerified=true` and clears the OTP.

### `POST /api/auth/resend-otp`
Body `{ email }`.
- 404 `User not found` (allows user enumeration) · 200 `{ success, msg }`
- Emails the OTP through Resend. If the email fails, the error goes to the handler and returns 500.

### `GET /api/auth/profile` 🔒 *(test route)*
200 `{ success, msg: "Welcome to your profile!", user }`

### `POST /api/auth/add-service` 🔒 vendor *(test route that does nothing)*
200 `{ success, msg: "Vendor access granted!…" }`

---

## Services (`routes/serviceRoutes.js`, `controllers/serviceController.js`)

### `GET /api/services`
Query:
- `page` (default 1), `limit` (default 10, **no maximum**)
- `sort` (comma-separated field list, e.g. `-price,createdAt`)
- `search` (regex on `name`)
- **any other key** is passed into the Mongo filter. The operators `gt`, `gte`, `lt`, `lte` and `in` are rewritten to `$…` (⚠️ SEC-03). Example: `?price[lte]=500&category=Salon`.
- `select` is removed from the filter but **never applied**.
- Always adds `isActive:true`.

200 `{ success, count, total, page, totalPages, data: Service[] }`, with `vendor` populated as `{name, businessName}`.

### `GET /api/services/nearby`
Query `lng`, `lat` (required), `radius` in metres (default 5000, no cap).
- 400 `Please provide lng and lat`
- 200 `{ success, count, data }`, unpaginated, sorted by distance.
- **No frontend consumer.**

### `GET /api/services/:id`
- 404 if missing **or `isActive=false`** · 200 `{ success, data }` with the vendor populated as `{name, businessName}`
- An invalid ObjectId returns 500.

### `GET /api/services/vendor/my-services` 🔒
200 `{ success, count, data }`, covering all of the caller's services including paused ones. There is no vendor role check.

### `POST /api/services/add` 🔒 vendor
`multipart/form-data`: `name`, `description`, `price`, `category`, `whatsappNumber`, plus `images[]` (up to 4 files, 5MB each, image/* MIME, Cloudinary formats jpg/jpeg/png/webp, cropped to 800×600).
- 400 `Vendor location not found…` · 201 `{ success, message, data }`

### `PUT /api/services/:id` 🔒 vendor, owner
JSON or multipart. Any body field except `vendor`, `averageRating`, `numOfReviews` and `location` is applied (⚠️ SEC-04). If any `images` files are uploaded, **all** existing images are destroyed and replaced (⚠️ BUG-06).
- 404 / 403 `Forbidden: You don't own this service` · 200 `{ success, data }`

### `DELETE /api/services/:id` 🔒 vendor, owner
Destroys the Cloudinary images, then hard-deletes the document.
- 200 `{ success, message: "Service removed from marketplace" }`

---

## Bookings (`routes/bookingRoutes.js`, `controllers/bookingController.js`)

### `POST /api/bookings/create` 🔒 (any role)
Body `{ serviceId, scheduledDate, address? }`.
- 404 `Service not found` · 400 `This service is currently unavailable` · 400 `You cannot book your own service` · 400 `Please update your location in profile first`
- 201 `{ success, msg, booking }`
- Side effect: a `booking_new` notification and an email to the vendor. These are awaited, so they add latency.
- `scheduledDate` isn't validated for being in the future. A missing date gives a Mongoose error, which returns 500.

### `GET /api/bookings/my-bookings` 🔒
Vendors get bookings where `vendor = me`. Everyone else gets bookings where `customer = me`.
- 200 `{ success, count, bookings }`. Populates `service(name category price images)`, `customer(name email phoneNumber)` and `vendor(name email businessName whatsappNumber*)`. `*` is not a User field, so it is always absent.

### `PATCH /api/bookings/update/:id` 🔒 participant
Body `{ status }`, one of `pending, confirmed, in-progress, completed, cancelled`.
- 400 invalid status · 404 · 403 `Access Denied` (not a participant) · 403 `Customers can only cancel bookings` · 400 `Cannot cancel at this stage` · 400 `Cannot change from "x" to "y"`
- 200 `{ success, msg, booking }`
- Side effect: notifies the other party, in-app and by email.

---

## Profile (`routes/profileRoutes.js`, `controllers/profileController.js`), all 🔒

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/profile` | — | `{ success, data: User }` |
| PUT | `/api/profile` | `{ name?, businessName?, phoneNumber? }` | `{ success, msg, data }` |
| POST | `/api/profile/photo` | multipart `profilePhoto` (2MB, cropped 400×400 to the face) | `{ success, msg, data }`. The old photo is deleted |

---

## Reviews (`routes/reviewRoutes.js`, `controllers/reviewController.js`)

| Method | Path | Auth | Body | Response / errors |
|---|---|---|---|---|
| GET | `/api/reviews/service/:serviceId` | public | — | `{ success, count, data }` with the customer populated as `{name, profilePhoto}`. Unpaginated |
| POST | `/api/reviews` | 🔒 | `{ serviceId, rating 1–5, comment ≤500 }` | 201 `{ success, data }` · 403 no completed booking · 400 already reviewed |
| GET | `/api/reviews/can-review/:serviceId` | 🔒 | — | `{ success, canReview, hasReviewed, hasBooking }` |
| DELETE | `/api/reviews/:id` | 🔒 owner | — | `{ success, msg }` · 404 · 403 |

---

## Notifications (`routes/notificationRoutes.js`, `controllers/notificationController.js`), all 🔒

| Method | Path | Response | Notes |
|---|---|---|---|
| GET | `/api/notifications` | `{ success, unreadCount, data }` (last 20) | |
| PATCH | `/api/notifications/read-all` | `{ success, msg }` | |
| PATCH | `/api/notifications/:id/read` | `{ success }` | ⚠️ SEC-09: no owner filter |
| DELETE | `/api/notifications/clear` | `{ success, msg }` | Deletes all of the caller's notifications |

Notification `type` enum: `booking_new`, `booking_confirmed`, `booking_cancelled`, `booking_completed`, `booking_inprogress`, `review_new` (never emitted).

---

## Client usage map
| Endpoint | Client caller |
|---|---|
| auth/* | `services/authService.js` → Login, Signup, VerifyOTP |
| GET services | `serviceService.getAllServices` → `AllServices.jsx:149` |
| GET services/:id | `serviceService.getServiceById` → `ServiceDetail.jsx:92` |
| GET services/nearby | `serviceService.getNearbyServices`, **unused** |
| GET vendor/my-services | `serviceService.getMyServices` → `VendorDashboard.jsx:45` |
| POST add / PUT :id | `AddServiceForm.jsx:100-107` (direct axios) and `serviceService.updateService` (toggle) |
| DELETE :id | `serviceService.deleteService` |
| bookings/* | `bookingService` (Customer, BookingModal) and direct axios (VendorDashboard) |
| profile/* | `ProfileSettings.jsx` (direct axios) |
| reviews/* | `ReviewSection.jsx` (direct axios) |
| notifications/* | `NotificationBell.jsx` (direct axios) |
| auth/profile, auth/add-service | `authService.getProfile` is defined but unused · add-service has no caller |

## Proposed future contract (not implemented)
- Versioned prefix `/api/v1`.
- RESTful paths: `POST /bookings`, `PATCH /bookings/:id/status`, `GET /me`, `PATCH /me`, `GET /services?category=&q=&near=lng,lat&radius=&page=`.
- Envelope `{ success, data, meta: { page, limit, total } }` or `{ success:false, error: { code, message, fields? } }`.
- OpenAPI spec generated from Zod schemas.


---

# Part B — Target API surface (Supabase + Next.js)

> **Status:** **Approved** (ADR-003, 2026-11-17). The "Proposed future contract" above (REST `/api/v1`) is **superseded**. Nothing has been implemented yet.
> The browser and server talk to Supabase through **supabase-js**, which wraps PostgREST, RPC, Auth, Storage and Realtime, and to Next.js through **Server Actions**. Custom HTTP endpoints exist only where an external caller needs them: auth confirmation and webhooks.

## B1. Endpoint migration map (all 27 current route handlers + health)

| # | Current endpoint | Target | Mechanism | Auth |
|---|---|---|---|---|
| 1 | `POST /api/auth/signup` | `signUpAction(formData)` → `supabase.auth.signUp` | Server Action | anon |
| 2 | `POST /api/auth/login` | `signInAction` → `signInWithPassword` (or `signInWithOtp`) | Server Action | anon |
| 3 | `POST /api/auth/verify-otp` | `GET /auth/confirm?token_hash&type` → `verifyOtp` | Route Handler | anon |
| 4 | `POST /api/auth/resend-otp` | `resendConfirmationAction` → `auth.resend` | Server Action | anon |
| 5 | `GET /api/auth/profile` (test) | **Removed.** Server code calls `getUser()` + selects `profiles` | — | — |
| 6 | `POST /api/auth/add-service` (test) | **Removed** | — | — |
| 7 | `GET /api/services` | `rpc('search_services', {...})` | RPC (security invoker) | anon |
| 8 | `GET /api/services/nearby` | same RPC with `p_lng`, `p_lat`, `p_radius_m` | RPC | anon |
| 9 | `GET /api/services/:id` | `from('services').select('*, service_images(*), category:categories(*), vendor:vendors(business_name, slug, bio, logo_path, status)').eq('slug', slug).single()` | PostgREST under RLS | anon |
| 10 | `GET /api/services/vendor/my-services` | `from('services').select(...).eq('vendor_id', uid).order('created_at', {ascending:false})` | PostgREST under RLS | vendor |
| 11 | `POST /api/services/add` | `createServiceAction` → insert `services` + signed uploads + insert `service_images` | Server Action | vendor |
| 12 | `PUT /api/services/:id` | `updateServiceAction` (allowed columns only) + `reorderImagesAction` / `deleteImageAction` | Server Action | vendor (owner) |
| 13 | `DELETE /api/services/:id` | `rpc('soft_delete_service', { p_service_id })` | RPC (definer) | vendor (owner) |
| 14 | `POST /api/bookings/create` | `rpc('create_booking', {...})` via `createBookingAction` | RPC (definer) | authenticated |
| 15 | `GET /api/bookings/my-bookings` | `from('bookings').select('*, service:services(title,slug), …').order(...).range(...)` | PostgREST under RLS | participant |
| 16 | `PATCH /api/bookings/update/:id` | `rpc('transition_booking', { p_booking_id, p_to, p_reason })` | RPC (definer) | participant |
| 17 | `GET /api/profile` | `from('profiles').select().eq('id', uid).single()` (+ `vendors`) | PostgREST under RLS | self |
| 18 | `PUT /api/profile` | `updateProfileAction` (column-granted fields) | Server Action | self |
| 19 | `POST /api/profile/photo` | signed upload to `avatars/{uid}/…` + update `avatar_path` | Server Action + Storage | self |
| 20 | `GET /api/reviews/service/:serviceId` | `from('reviews').select('rating, comment, author_name, created_at').eq('service_id', id).range(...)` | PostgREST under RLS | anon |
| 21 | `POST /api/reviews` | `rpc('create_review', { p_booking_id, p_rating, p_comment })` | RPC (definer) | customer |
| 22 | `GET /api/reviews/can-review/:id` | `from('bookings').select('id').eq('service_id', id).eq('status','completed')` left-joined to `reviews`, where no review exists | PostgREST under RLS | customer |
| — | `DELETE /api/reviews/:id` | `from('reviews').delete().eq('id', id)` | PostgREST under RLS | owner |
| — | `GET/PATCH/DELETE /api/notifications*` | `from('notifications')` select/delete; `rpc('mark_notifications_read', { p_ids })`; Realtime channel | PostgREST, RPC and Realtime | owner |
| — | `GET /` (health) | `GET /api/health` Route Handler (checks the database with a trivial query) | Route Handler | public |

Rows 1–22 are listed one by one. The review delete and the 4 notification routes are grouped. Together that covers all 27 route handlers (auth 6, services 7, bookings 3, profile 3, reviews 4, notifications 4) plus `GET /`.

## B2. Proposed RPC signatures
```sql
search_services(p_q text default null, p_category text default null,
                p_min_paise int default null, p_max_paise int default null,
                p_lng float8 default null, p_lat float8 default null, p_radius_m int default 10000,
                p_sort text default 'newest',   -- newest | price_asc | price_desc | rating | distance
                p_limit int default 20, p_offset int default 0)
  returns table (id uuid, slug text, title text, price_paise int, currency char(3), avg_rating numeric,
                 review_count int, duration_minutes int, category_slug text, vendor_name text,
                 vendor_slug text, vendor_status vendor_status, cover_path text,
                 distance_m float8, total_count bigint)   -- implemented; cover_path is a Storage path

create_booking(p_service_id uuid, p_scheduled_at timestamptz, p_address_id uuid, p_notes text default null)
  returns public.bookings
transition_booking(p_booking_id uuid, p_to public.booking_status, p_reason text default null)
  returns public.bookings
create_review(p_booking_id uuid, p_rating int, p_comment text default null) returns public.reviews
soft_delete_service(p_service_id uuid) returns void
get_booking_contact(p_booking_id uuid)
  returns table (name text, phone_e164 text, whatsapp_e164 text, email text)
mark_notifications_read(p_ids uuid[] default null) returns int
get_my_vendor() returns table (... whatsapp_e164, lng, lat, service_radius_m, status ...)   -- own vendor row
-- Admin (PD-13 option b; each writes admin_audit_log)
admin_set_vendor_status(p_vendor_id uuid, p_status vendor_status, p_note text default null) returns vendor_status
admin_set_review_hidden(p_review_id uuid, p_hidden boolean, p_note text default null) returns void
admin_set_service_hidden(p_service_id uuid, p_hidden boolean, p_note text default null) returns void
```
Implemented in `supabase/migrations/20261117000200_functions.sql`. Types are generated in `supabase/types/database.types.ts`.

## B3. Error codes (raised by the RPCs, mapped by `lib/errors.ts`)
| SQLSTATE / code | Meaning | UI |
|---|---|---|
| `P0001` + `HINT 'invalid_transition'` | Status change not allowed | Toast with the reason |
| `P0001` + `HINT 'not_eligible'` | Review not allowed | Inline message |
| `P0001` + `HINT 'service_unavailable'` | Service paused, deleted or vendor suspended | Inline message |
| `22023` | Invalid parameter (schedule too soon or too far, rating, location, sort, missing reason). The `HINT` names the field rule | Field error |
| `P0002` | Not found, or not visible to the caller (same error, so IDs can't be probed) | Not found |
| `23505` | Unique violation (duplicate review or booking) | Conflict message |
| `23514` | Check violation | Field error |
| `42501` / PostgREST `PGRST301` | RLS or permission denied | Forbidden |
| PostgREST `PGRST116` | `.single()` found no rows | Not found |

## B4. Contract & typing
- **Database types** are generated with `supabase gen types typescript` into `lib/database.types.ts` and checked in CI, so drift fails the build.
- **Zod schemas** in `features/*/schemas.ts` are the input contract for Server Actions and forms.
- **Server Action results** use the `ActionResult<T>` union ([BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md) Part B §B5).
- **No OpenAPI** is needed for internal use, because the app consumes the types directly. If a public API is ever offered, document PostgREST with its built-in OpenAPI output.
