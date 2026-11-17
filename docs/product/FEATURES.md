# Feature Inventory

Status legend: see [../README.md](../README.md). Issue IDs refer to [../audit/BUGS_AND_ISSUES.md](../audit/BUGS_AND_ISSUES.md).

## Summary

| # | Feature | User | Status |
|---|---|---|---|
| F01 | Signup (customer/vendor) with location | Guest | Broken or Incomplete |
| F02 | Email OTP verification | Guest | Broken or Incomplete (security) |
| F03 | Login with OTP second step | Guest | Broken or Incomplete (security) |
| F04 | Resend OTP | Guest | Partially Implemented |
| F05 | Session handling / protected routes | All | Partially Implemented |
| F06 | Logout | All | Partially Implemented |
| F07 | Explore / browse services | Guest, All | Broken or Incomplete |
| F08 | Search and category filter | Guest, All | Partially Implemented |
| F09 | Nearby services ("near me") | — | Backend Only |
| F10 | Service detail page and image gallery | Guest, All | Fully Implemented |
| F11 | Vendor: create service with images | Vendor | Fully Implemented |
| F12 | Vendor: edit service | Vendor | Broken or Incomplete |
| F13 | Vendor: pause / activate service | Vendor | Partially Implemented |
| F14 | Vendor: delete service | Vendor | Partially Implemented |
| F15 | Customer: create booking | Customer (any user) | Partially Implemented |
| F16 | Booking lifecycle (vendor transitions) | Vendor | Fully Implemented |
| F17 | Customer: cancel booking | Customer | Fully Implemented |
| F18 | Customer: booking list, status filter, CSV export | Customer | Fully Implemented |
| F19 | WhatsApp contact with vendor | Customer | Broken or Incomplete |
| F20 | Reviews and ratings | Customer | Fully Implemented |
| F21 | In-app notifications (polling) | All | Fully Implemented |
| F22 | Email notifications | All | Requires Verification |
| F23 | Profile view/edit (name, phone, business name) | All | Partially Implemented |
| F24 | Profile photo upload | All | Fully Implemented |
| F25 | Vendor overview (revenue, stats, chart, map) | Vendor | Partially Implemented |
| F26 | Customer overview (stats, map, latest booking) | Customer | Fully Implemented |
| F27 | Dashboard search box | All | UI Only |
| F28 | Footer links / social / "API Docs" | Guest | UI Only |
| F29 | Admin / moderation | — | Not Implemented |
| F30 | Password reset | — | Not Implemented |
| F31 | Payments | — | Not Implemented |
| F32 | Update location/address after signup | — | Not Implemented |
| F33 | Vendor verification ("Verified Provider") | — | Not Implemented (copy only) |
| F34 | "New review" notification (`review_new`) | Vendor | Not Implemented (enum only) |

---

## Details

### F01 — Signup
- **Purpose:** Create a customer or vendor account. Location is mandatory.
- **Frontend:** `Client/veny-frontend/src/pages/Signup.jsx`. A role toggle, browser geolocation and Nominatim reverse geocoding (`Signup.jsx:131`), plus an `AddressModal`.
- **Backend:** `POST /api/auth/signup`, handled by `authController.signup` (`Server/src/controllers/authController.js:16`).
- **Models:** User.
- **Problems:**
  - SEC-01: the OTP is returned in the response.
  - BUG-02: the address is dropped silently.
  - BUG-03: when geolocation is denied or the address is entered manually, the account silently gets hardcoded Noida coordinates.
  - The only password rule is length ≥ 6.
  - Non-vendor roles aren't validated beyond the schema enum.
- **Missing:** terms acceptance, phone number at signup, a password strength rule.

### F02 — Email OTP verification
- **Frontend:** `pages/VerifyOTP.jsx`. It compares the input against `location.state.frontendOtp` before it calls the API (`VerifyOTP.jsx:30-35`).
- **Backend:** `POST /api/auth/verify-otp` (`authController.js:100`). The OTP is a 6-digit string with a 10-minute expiry, stored in **plaintext** (`User.js:61`).
- **Problems:**
  - SEC-01 and SEC-02: the OTP is visible to the client, so verification proves nothing.
  - SEC-08: there is no attempt limit.

### F03 — Login (password + OTP)
- **Frontend:** `pages/Login.jsx`. It calls login, sends the OTP with EmailJS **from the browser** (`Login.jsx:37`), then navigates to `/verify-otp`.
- **Backend:** `POST /api/auth/login` (`authController.js:65`). The password is checked with bcrypt, a fresh OTP is generated and **returned in the response** (`authController.js:88`). The JWT is only issued by verify-otp.
- **Problems:**
  - SEC-01: the second factor is ineffective.
  - Every login needs an email round-trip, which is heavy UX friction for no security gain as implemented.

### F04 — Resend OTP
- **Backend:** `POST /api/auth/resend-otp` (`authController.js:149`). This is the **only** path that emails the OTP server-side, via Resend (`utils/sendEmail.js`). It does not return the OTP.
- **Problems:**
  - Inconsistent delivery: signup and login use EmailJS, resend uses Resend.
  - It is user-enumerable: an unknown email returns 404 `"User not found"`.
  - It has no per-email throttle.

### F05 — Session / protected routes
- **Frontend:**
  - `components/ProtectedRoute.jsx` decodes the JWT `exp` claim client-side.
  - `api/axiosClient.js:9-16` attaches the Bearer token.
  - `api/axiosClient.js:19-28` clears storage and redirects on a 401.
  - Only `/dashboard` is protected (`App.jsx:46`).
- **Backend:** `protect` middleware (`middleware/authMiddleware.js:8`). The JWT carries `{id, role}` and expires after 24h (`authController.js:7-11`).
- **Problems:**
  - SEC-06: the token is stored in localStorage.
  - The `requiredRole` prop is never used.
  - `Dashboard.jsx` reads `user` from localStorage and spins forever if it is missing (`pages/Dashboard.jsx:13`).

### F06 — Logout
- `localStorage.clear()` followed by a navigation (`VendorDashboard.jsx:94`, `CustomerDashboard.jsx:90`).
- **Problems:** no server-side invalidation. Logout is only reachable from the dashboards, and the public Navbar has no logout or account entry (`components/Navbar.jsx:13-17`).

### F07 — Explore / browse
- **Frontend:** `pages/AllServices.jsx`, with a hero, category chips and a card grid.
- **Backend:** `GET /api/services` (`serviceController.js:180`). It supports filter, sort, pagination and `search`.
- **Problems:**
  - BUG-04: the UI calls the API without params (`AllServices.jsx:149`), so it gets the default `limit=10` and **never paginates**. Only the 10 newest services can ever appear.
  - The hero "Scan Galaxy" button has no handler (`AllServices.jsx:46`).

### F08 — Search & category filter
- Filtering is client-side over the 10 loaded items (`AllServices.jsx:163-176`). The server-side `search` and `category` params exist but are unused.
- **Status:** Partially Implemented. It works only on the first page.

### F09 — Nearby services
- **Backend:** `GET /api/services/nearby?lng&lat&radius` uses `$near` (`serviceController.js:232-255`).
- **Frontend:** `serviceService.getNearbyServices` exists (`services/serviceService.js:30`), but **no component calls it**.
- **Problems:**
  - Non-numeric `lng`/`lat` values produce NaN, which surfaces as a 500 error (BUG-01).
  - There is no `radius` upper bound.

### F10 — Service detail
- `pages/ServiceDetail.jsx` with `ImageGallery`, `ReviewSection` and `BookingModal`, backed by `GET /api/services/:id`.
- **Problems:**
  - Static claims: "Avg. 2 Hours" (`ServiceDetail.jsx:162`), "Verified Provider" and "Instant Booking".
  - A paused service returns 404, even to its owner (`serviceController.js:164`).

### F11 — Create service
- **Frontend:** `components/AddServiceForm.jsx`, which posts multipart data to `/services/add`.
- **Backend:** `POST /api/services/add`, behind `protect` and `authorize('vendor')`, using multer and Cloudinary with a maximum of 4 images at 5MB each (`routes/serviceRoutes.js:43`). The service location is copied from the vendor (`serviceController.js:37`).
- **Problems:**
  - The location is a snapshot that never updates.
  - `whatsappNumber` has no format validation.

### F12 — Edit service
- `PUT /api/services/:id` (`serviceController.js:79`).
- **Problems:**
  - BUG-06: removing an existing image is UI-only (`AddServiceForm.jsx:70`). Uploading any new image deletes **all** old images (`serviceController.js:95-107`).
  - SEC-04: mass assignment.
  - On a successful edit the form resets its own state, but that path shares code with create.

### F13 — Pause / activate
- `VendorDashboard.handleToggle` (`VendorDashboard.jsx:67`) sends `PUT {isActive}`.
- **Problems:**
  - A paused service disappears from Explore. That is intended.
  - The owner can't open its detail page (`serviceController.js:164`).
  - Bookings already made against a paused service are unaffected, with no warning to the vendor.

### F14 — Delete service
- `DELETE /api/services/:id` deletes the document and its Cloudinary images (`serviceController.js:126`).
- **Problems:** a **hard delete with no booking or review check**. Existing bookings keep a dangling `service` reference, so dashboards show an empty name. Reviews are orphaned.

### F15 — Create booking
- **Frontend:** `components/BookingModal.jsx`, with a datetime picker and the address taken from localStorage.
- **Backend:** `POST /api/bookings/create` (`bookingController.js:11`). It notifies the vendor in-app and by email.
- **Problems:**
  - BUG-02: the address is always `"Home"`.
  - There is **no role check**, so a vendor can book another vendor's service.
  - `scheduledDate` is not validated server-side (past dates are accepted).
  - Duplicate bookings aren't prevented.
  - Invalid `serviceId` causes a CastError, which surfaces as a 500.

### F16 — Booking lifecycle (vendor)
- The state machine lives in `bookingController.js:129-143`. Each transition emits a notification (`bookingController.js:149-189`).
- UI buttons in `VendorDashboard.jsx:360-382`.
- **Status:** Fully Implemented. See the state diagram in [USER_FLOWS.md](USER_FLOWS.md).

### F17 — Customer cancel
- A customer may set `cancelled` while the booking is pending or confirmed (`bookingController.js:119-126`). The UI is in `CustomerDashboard.jsx:344`.

### F18 — Customer booking list
- Filter tabs and a client-side CSV export (`CustomerDashboard.jsx:62-81`).
- **Problem:** the CSV fields aren't quoted or escaped, so a service name with a comma breaks the columns. There is no pagination on `my-bookings`.

### F19 — WhatsApp contact
- `CustomerDashboard.jsx:315,356`.
- **Problems (BUG-05):** `booking.vendor.whatsappNumber` is always undefined because the field lives on **Service**, not User, so the button never renders. The URL also prepends `91` to a number the vendor was told to enter as "+91 …".

### F20 — Reviews & ratings
- **Frontend:** `components/ReviewSection.jsx`.
- **Backend:** `routes/reviewRoutes.js`. Only a customer with a **completed** booking can review, once per service, enforced by a unique index (`models/Review.js:29`). The service's `averageRating` and `numOfReviews` are recalculated by post hooks (`Review.js:32-50`).
- **Problems:**
  - The hooks are fire-and-forget (not awaited).
  - There is no vendor reply and no moderation.
  - `review_new` is never sent to the vendor.

### F21 — In-app notifications
- **Frontend:** `components/NotificationBell.jsx`, polling every 30s (`NotificationBell.jsx:40`). It is only shown in the dashboards.
- **Backend:** `routes/notificationRoutes.js`. It returns the last 20 notifications plus the unread count.
- **Problems:**
  - SEC-09: `markOneRead` has no owner check.
  - Polling uses up the shared rate-limit budget (PERF-03).

### F22 — Email notifications
- `createNotification` → `sendEmail` via Resend, from `onboarding@resend.dev` (`utils/sendEmail.js:13`).
- **Requires Verification:** whether delivery works at all. Resend's shared test sender can typically only deliver to the account owner's own address. The 7-commit history of email-provider changes suggests delivery has been unreliable.
- **Problem:** SEC-07, HTML injection into the email template.

### F23 — Profile edit
- `components/ProfileSettings.jsx`, backed by `PUT /api/profile` (`profileController.js:21`).
- **Problems:**
  - Location and address can't be edited.
  - A vendor's `businessName` could be blanked (Requires Verification: how update validators run the `required` function).
  - Phone numbers have no format validation.

### F24 — Profile photo
- `POST /api/profile/photo` uploads to Cloudinary with a face crop, at most 2MB, and deletes the old photo (`profileController.js:51`).

### F25 — Vendor overview
- Stat cards, an earnings bar chart, a map and recent orders (`VendorDashboard.jsx:205-262`).
- **Problems:**
  - "Total Revenue" is the sum of `totalPrice` on completed bookings. No money moves, so the figure is a *notional* revenue.
  - The chart buckets by `createdAt` month name rather than the completion date (`VendorDashboard.jsx:111`).

### F27 — Dashboard search
- `<input type="search">` with no state or handler (`VendorDashboard.jsx:175`, `CustomerDashboard.jsx:172`).

### F28 — Footer
- Every link is `href="#"` (`components/Footer.jsx:32,46,59`). "All Systems Operational" is a static claim (`Footer.jsx:75`).
