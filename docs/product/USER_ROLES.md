# User Roles & Permissions

## Current implementation

### Roles that exist
Exactly two roles are defined (`Server/src/models/User.js:25-29`):

| Role | How assigned | Extra fields |
|---|---|---|
| `customer` | Default at signup | — |
| `vendor` | Chosen with the toggle at signup (`Signup.jsx:293`) | `businessName`, required (`User.js:30-34`) |

- A user picks their own role at signup. Nothing approves or verifies vendors.
- There is no **admin, super-admin or moderator** role. A commented placeholder hints at one: `// router.get('/admin-stats', protect, authorize('admin', 'vendor'), controller);` (`routes/authRoutes.js:32`).
- Once chosen, a role can't be changed. `PUT /api/profile` ignores `role` (`profileController.js:23`).
- Guests (unauthenticated visitors) can browse Explore, service detail pages and reviews.

### How authorization is enforced
- **Authentication:** `protect` checks a Bearer JWT and loads `req.user` from the database (`middleware/authMiddleware.js:8-45`).
- **Role check:** `authorize(...roles)` compares against `req.user.role` (`authMiddleware.js:51-62`). It is used **only** on service create, update and delete, and on the test route `/api/auth/add-service`.
- **Ownership checks** are done inside controllers. Services check `vendor === req.user`, bookings check that the user is the vendor or the customer, and reviews check the customer. Notifications are mostly scoped by `user`, with one exception (SEC-09).
- **Frontend:** `ProtectedRoute` only checks that a token exists and hasn't expired. `Dashboard.jsx` chooses the vendor or customer dashboard from `localStorage.user.role`, which is **client-trusted**. The server still enforces permissions, so this only affects which UI loads.

### Permission matrix (as implemented)

✅ allowed · ❌ denied · 🔸 allowed by the API although the UI doesn't intend it

| Endpoint | Guest | Customer | Vendor | Notes |
|---|---|---|---|---|
| `POST /api/auth/signup, login, verify-otp, resend-otp` | ✅ | ✅ | ✅ | Public |
| `GET /api/auth/profile` | ❌ | ✅ | ✅ | Test route |
| `POST /api/auth/add-service` | ❌ | ❌ | ✅ | Test route that does nothing |
| `GET /api/services`, `/nearby`, `/:id` | ✅ | ✅ | ✅ | Active services only |
| `GET /api/services/vendor/my-services` | ❌ | 🔸 (returns an empty list) | ✅ | No `authorize('vendor')` |
| `POST /api/services/add` | ❌ | ❌ | ✅ | |
| `PUT/DELETE /api/services/:id` | ❌ | ❌ | ✅ owner only | |
| `POST /api/bookings/create` | ❌ | ✅ | 🔸 | A vendor can book *other* vendors' services. Booking one's own service is blocked |
| `GET /api/bookings/my-bookings` | ❌ | ✅ (as customer) | ✅ (as vendor only) | A vendor's own customer-side bookings are **never listed** |
| `PATCH /api/bookings/update/:id` | ❌ | ✅ cancel only, when pending or confirmed | ✅ state machine | Party check at `bookingController.js:111-116` |
| `GET/PUT /api/profile`, `POST /api/profile/photo` | ❌ | ✅ self | ✅ self | |
| `GET /api/reviews/service/:id` | ✅ | ✅ | ✅ | |
| `POST /api/reviews` | ❌ | ✅ needs a completed booking | 🔸 (only if they booked as a customer) | |
| `GET /api/reviews/can-review/:id` | ❌ | ✅ | ✅ | |
| `DELETE /api/reviews/:id` | ❌ | ✅ own review only | ✅ own review only | |
| `GET /api/notifications`, `PATCH read-all`, `DELETE clear` | ❌ | ✅ self | ✅ self | |
| `PATCH /api/notifications/:id/read` | ❌ | 🔸 **any notification id** | 🔸 **any notification id** | SEC-09 (IDOR) |

### What each role can do in the UI
| Capability | Customer | Vendor |
|---|---|---|
| Browse and search Explore | ✅ | ✅ |
| Book a service | ✅ | ✅ (book button shown; API allows other vendors' services) |
| Dashboard tabs | Overview, My Bookings, Explore (link), Settings | Overview, My Services, Bookings, Settings |
| Manage listings | — | Create, edit, pause, delete |
| Advance a booking | Cancel | Confirm, Cancel, Start Work, Mark Complete |
| Review | After a completed booking | — |
| Notifications | ✅ | ✅ |

## Identified problems
- An inconsistent role model: a vendor can act as a customer when booking, but can never see those bookings. `getMyBookings` branches on role (`bookingController.js:72-74`).
- No platform-level authority, so abuse, fraud and disputes can't be handled.
- Role enforcement is ad hoc in controllers, with no central policy layer.
- The `/unauthorized` page exists (`App.jsx:56`), but nothing routes to it because `requiredRole` is never passed.

## Proposed future (not implemented)
- Decide explicitly whether a vendor may also book. If yes, list bookings by participation rather than by role.
- Add an `admin` role for moderation (users, listings, reviews), behind a separate admin UI. **Product decision required.**
- Introduce a central permissions map (role × action), checked by middleware.
- Vendor onboarding status: `pending_verification`, `verified` or `suspended`.
