# Security Audit

Scope: static review of the code in `Server/src` and `Client/veny-frontend/src`. No secrets are present in the repository, and none are reproduced here. `.env*` files are git-ignored (`.gitignore:20-25`). None exist in the working copy, and no `.env*` file was found in the tree. No dynamic testing was performed.

## Summary

| Area | Rating | Key IDs |
|---|---|---|
| Password storage | 🟢 Adequate | bcryptjs at cost 10, `select:false` |
| OTP / email verification | 🔴 Broken | SEC-01, SEC-02, SEC-08 |
| JWT / session | 🟠 Weak | SEC-06 |
| Authorization (RBAC + ownership) | 🟡 Mostly correct, with gaps | SEC-04, SEC-09, BE-09 |
| Input validation / NoSQL injection | 🟠 Weak | SEC-03, SEC-10 |
| XSS (web) | 🟢 Low risk | React escaping; no `dangerouslySetInnerHTML` |
| XSS / HTML injection (email) | 🟠 | SEC-07 |
| CSRF | 🟢 N/A today | Bearer header, no cookies. Becomes relevant if cookies are adopted |
| CORS | 🟠 | SEC-05 |
| Rate limiting | 🟡 | SEC-08, BE-11 |
| File upload | 🟢 Mostly adequate | See below |
| Information exposure | 🟡 | SEC-11, SEC-12, SEC-13 |
| Dependencies | ⚪ Requires Verification | V-03 |

## Findings

### 1. Password hashing
- `bcrypt.genSalt(10)` and `hash` happen in signup (`authController.js:30-31`). `compare` is used on login (`:72`).
- `password` has `select: false` (`User.js:23`), and `protect` explicitly excludes it (`authMiddleware.js:22`).
- Gaps: a minimum length of 6 with no complexity or breach check, no password change or reset flow, and hashing lives in the controller rather than a model hook. That matters if a future password-reset path is added.

### 2. OTP / email verification (Critical)
- **SEC-01:** the OTP is returned in both signup (`authController.js:54`) and login (`:88`) responses. Anyone who calls the API directly receives the code without having access to the inbox.
- **SEC-02:** the client sends the email itself through EmailJS (`Login.jsx:37`, `Signup.jsx:239`). The EmailJS public key is shipped in the bundle by design. Whether the EmailJS template restricts recipients or content should be checked in the EmailJS dashboard (V).
- **SEC-08:**
  - Uses `Math.random()`, which isn't cryptographically secure.
  - The code is stored in plaintext (`User.js:61`).
  - The comparison is a plain string compare.
  - There's no attempt counter.
  - The 10-minute expiry is good.
  - The OTP is cleared after a successful verification (`:123-125`), which is good.
- **Consequence:** the `isVerified` flag gives no assurance that a user owns their email. Combined with self-selected vendor roles, anyone can register as a vendor using a real business's email.

### 3. JWT / session
- HS256 with `JWT_SECRET` and a 24h expiry. The payload `{id, role}` is fine, and `protect` re-reads the user from the database.
- Stored in `localStorage` (SEC-06). Logout is client-only. There's no rotation and no revocation.
- `protect` is lenient about the header format: it checks `startsWith('Bearer')` and then splits on a space, so `"Bearer"` with no token crashes into the `jwt.verify(undefined)` path, which is handled as a `JsonWebTokenError` and returns 401. Acceptable.
- There's no startup check that `JWT_SECRET` exists or is long enough (V-07).

### 4. Authorization
- **Correct:**
  - Service update and delete check ownership (`serviceController.js:87,134`).
  - Booking update checks the parties (`bookingController.js:111-116`) and enforces the state machine.
  - Review delete checks the owner (`reviewController.js:83`).
  - The notification list, read-all and clear are scoped to `req.user`.
- **Gaps:**
  - SEC-09: `markOneRead` updates by `_id` only.
  - BE-09: `my-services` has no role check (harmless).
  - BE-03: any role can book.
  - SEC-04: mass assignment in a service update.
- The client-side role (`localStorage.user.role`) decides which dashboard loads. The server enforces permissions, so tampering only changes the UI.

### 5. Input validation & NoSQL injection
- No validation library is used. Request bodies go straight into queries (`User.findOne({ email })` in `authController.js:27,68,104,152`).
  - With `express.json`, a body such as `{"email":{"$gt":""}}` reaches Mongoose as an object.
  - Mongoose casting for String paths and its `sanitizeFilter` default decide whether the operator is honoured. This is **Requires Verification (V-04)**.
  - If operators pass through, login still requires a bcrypt match (`bcrypt.compare` with a non-string password would throw, giving a 500), but `resend-otp` and `verify-otp` could act on an arbitrary first user. The attacker still needs the OTP, which isn't returned by resend.
  - Treat this as **a high-priority potential risk until verified**.
- `getAllServices` rewrites `gt|gte|lt|lte|in` into Mongo operators from any query key (SEC-03), and `search` becomes an unescaped `$regex` (ReDoS, full scan). `limit` is uncapped.
- `getNearbyServices` uses unbounded `radius` and NaN coordinates.

### 6. XSS
- Web: React escapes all rendered values. No `dangerouslySetInnerHTML` or `innerHTML` exists in `src/` (checked with grep). Leaflet popup content is passed as JSX, which is safe. `Map.jsx` `divIcon` HTML is static.
- Email: SEC-07. `sendEmail.js:26` interpolates `options.message` into HTML. The message embeds `customer.name`, `service.name` and `vendor.businessName`, all user-controlled.

### 7. CORS / headers
- `origin: '*'` (SEC-05). Helmet is enabled with CSP disabled, which is acceptable for a JSON API. The SPA's CSP, configured on Vercel, is Requires Verification.

### 8. Rate limiting
- There's one limiter: 100 requests per 15 minutes per IP on `/api`, with `trust proxy` set to 1, which is correct for Render. Auth endpoints get no stricter limit.
- Notification polling (2 requests every 30s) plus normal use can exhaust the budget for users behind a shared NAT.

### 9. File uploads
- multer enforces 2MB for profiles and 5MB for services, with at most 4 files. It filters on `image/*` MIME types, and Cloudinary enforces `allowed_formats` jpg/jpeg/png/webp server-side. `public_id` is server-generated.
- Gaps:
  - The MIME type is client-declared, though Cloudinary's format check mitigates that.
  - Multer and Cloudinary errors (such as a file too large) go through BUG-01 and return 500 instead of 400/413.
  - The old Cloudinary image is destroyed *before* the database update (`profileController.js:60-62`). If the update fails, the old image is lost.

### 10. Information exposure
- Test routes (SEC-11), enumeration (SEC-12), stack traces when `NODE_ENV` isn't `production` (SEC-13).
- `getMyBookings` returns customer `email` and `phoneNumber` to the vendor, and vendor `email` to the customer. That's acceptable for the business purpose but should be documented in a privacy policy.
- `morgan('dev')` logs URLs, including query strings. No secrets are sent in URLs today.

### 11. Dependencies
- `npm audit` wasn't run, because the audit was static-only (V-03).
- Noted from the versions:
  - `cloudinary@1.41.3` is the legacy major. v2 is current. It's tied to `multer-storage-cloudinary@4`, which hasn't been updated in years (V).
  - Everything else is recent: Express 5.2, Mongoose 9.6, React 19.2, Vite 8.
- Unused packages (`nodemailer` ×2, Redux) add supply-chain surface for no benefit.

## Priority remediation order
1. SEC-01 + SEC-02: server-only OTP.
2. Verify V-04, then add SEC-10 validation.
3. SEC-03: whitelist filters and cap `limit`.
4. SEC-04: explicit update fields.
5. SEC-08: hashed OTP, `crypto.randomInt` and attempt limits.
6. SEC-05, SEC-06, SEC-07, SEC-09, SEC-11, SEC-12, SEC-13.

**If production has real users,** consider forcing re-verification of accounts created while SEC-01 existed. This is a product decision that needs approval.
