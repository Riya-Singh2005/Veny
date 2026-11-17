# User Flows

All flows describe **current behaviour**. ⚠️ marks a confirmed defect, with its ID from [BUGS_AND_ISSUES.md](../audit/BUGS_AND_ISSUES.md).

## 1. Signup + email verification

```mermaid
sequenceDiagram
    actor U as Guest
    participant FE as Signup.jsx
    participant NOM as Nominatim (OSM)
    participant API as POST /api/auth/signup
    participant EJ as EmailJS (browser)
    participant V as VerifyOTP.jsx
    participant API2 as POST /api/auth/verify-otp

    U->>FE: choose role, fill name/email/password
    U->>FE: "Sync Location"
    FE->>FE: navigator.geolocation (5s timeout, 6s fallback)
    Note over FE: ⚠️ BUG-03 on deny/timeout/manual entry,<br/>coords = hardcoded Noida (28.5355, 77.3910)
    FE->>NOM: reverse geocode
    NOM-->>FE: display_name + address parts
    FE->>API: {name,email,password,role,businessName,location:{type,coordinates,address}}
    Note over API: ⚠️ BUG-02 location.address not in schema, dropped
    API-->>FE: 201 { otp: "123456" }  ⚠️ SEC-01
    FE->>EJ: send passcode to email (VITE_EMAILJS_*)
    FE->>V: navigate with state {email, frontendOtp}
    U->>V: enter OTP
    V->>V: compare with frontendOtp (client-side)
    V->>API2: {email, otp}
    API2-->>V: { token, user{id,name,role,email,location} }
    V->>V: localStorage token + user
    V-->>U: redirect /dashboard
```

**Problems on this flow:**
- Anyone can verify an email they don't own, because the OTP is in the API response (SEC-01).
- If EmailJS fails, the account is still created but left unverified. Signing up again then fails with "User already exists". The user's only way out is to log in, which sends a new OTP.
- A user who refreshes `/verify-otp` loses the router state and is redirected to `/login` (`VerifyOTP.jsx:19-21`).

## 2. Login (password + OTP)

```mermaid
flowchart TD
    A[Login.jsx: email + password] --> B[POST /api/auth/login]
    B -->|invalid| E1[400 Invalid credentials]
    B -->|not verified| E2[403 Please verify your email first]
    B -->|ok| C["200 { otp, name } ⚠️ SEC-01"]
    C --> D[EmailJS send from browser]
    D --> F[navigate /verify-otp with frontendOtp]
    F --> G[POST /api/auth/verify-otp]
    G --> H[JWT 24h -> localStorage]
    H --> I["navigate(from || /dashboard)"]
```

- An unverified user who gets the 403 has no button to resend the OTP. They'd have to know to sign up again, and that fails.

## 3. Browse → detail → book

```mermaid
flowchart LR
    X["/ (redirect)"] --> E["/explore AllServices"]
    E -->|"GET /api/services (no params) ⚠️ BUG-04 max 10"| E
    E --> D["/service/:id ServiceDetail"]
    D --> R[ReviewSection: GET /reviews/service/:id]
    D --> M[BookingModal]
    M -->|no token| T[toast: Please login, modal closes]
    M -->|token| P["POST /api/bookings/create {serviceId, scheduledDate, address:'Home' ⚠️ BUG-02}"]
    P --> N[Vendor notified: in-app + email]
```

- A guest who clicks "Initiate Mission" only sees a toast. Nothing redirects them to login or brings them back afterwards.

## 4. Booking lifecycle

```mermaid
stateDiagram-v2
    [*] --> pending: customer creates
    pending --> confirmed: vendor
    pending --> cancelled: vendor or customer
    confirmed --> in_progress: vendor ("Start Work")
    confirmed --> cancelled: vendor or customer
    in_progress --> completed: vendor ("Mark Complete")
    completed --> [*]
    cancelled --> [*]
```

Source: `Server/src/controllers/bookingController.js:118-143`. Each transition creates a notification for the other party (`bookingController.js:149-189`). On `completed`, the notification links to `/service/:id` and invites a review.

- No cancellation reason is recorded.
- Nothing handles no-shows, rescheduling or disputes.
- The customer can't contact the vendor because the WhatsApp button never shows (⚠️ BUG-05). The vendor sees the customer's `phoneNumber`, but only if the customer set one in their profile.

## 5. Review

```mermaid
flowchart TD
    S[ServiceDetail -> ReviewSection] --> L{logged in?}
    L -->|no| LG[Login link]
    L -->|yes| C[GET /reviews/can-review/:serviceId]
    C -->|completed booking & not reviewed| F[form: 1–5 stars + comment ≥5 chars]
    C -->|already reviewed| A[badge]
    C -->|no completed booking| N[Complete a booking to leave a review]
    F --> P[POST /api/reviews] --> H[post-save hook recalculates Service.averageRating]
```

## 6. Vendor service management

```mermaid
flowchart TD
    V[VendorDashboard → My Services] --> NEW[New Listing → AddServiceForm]
    NEW -->|multipart, ≤4 images| C[POST /api/services/add]
    V --> ED[Edit → AddServiceForm editingService]
    ED -->|new images present| R["PUT /:id ⚠️ BUG-06 deletes ALL old images"]
    ED -->|only removed existing| U["PUT /:id ⚠️ removal ignored"]
    V --> TG["Pause/Activate → PUT {isActive}"]
    V --> DL["Delete → window.confirm → DELETE /:id (hard delete, bookings orphaned)"]
```

## 7. Notifications

- The bell polls `GET /api/notifications` every 30s while a token exists (`NotificationBell.jsx:37-42`).
- Clicking an item marks it read and navigates to `notif.link`.
- The bell is **only** mounted inside the dashboards. Public pages never show it.

## Missing / inconsistent workflows
| Gap | Evidence |
|---|---|
| Password reset | No route exists |
| Resending the OTP from the login 403 state | `Login.jsx` handles only an error string |
| Changing location or address | `profileController.js:23` |
| Returning to the dashboard from public pages | Navbar links are fixed to Explore, Login and Signup (`Navbar.jsx:13-17`) |
| "Join as Vendor" CTA | Opens `/signup` with the role preset to customer (`Navbar.jsx:46`, `Signup.jsx:121`) |
| Login prompt from booking | Only a toast (`BookingModal.jsx:30-33`) |
| A vendor viewing their own bookings as a customer | `bookingController.js:72` |
| Duplicate Explore entry points | The dashboard "Explore" menu item and the CTA both navigate away from the dashboard layout |
