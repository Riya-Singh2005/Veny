# Veny — Product Overview

## Current implementation (inferred from code)

**Veny is a two-sided, location-aware marketplace for local home services.** Vendors list services such as cleaning or plumbing. Customers find a service, request a booking for a date and time, and follow it through to completion. After completion, the customer can leave a review.

The evidence for this reading:

| Signal | Evidence |
|---|---|
| Two account types | `Server/src/models/User.js:25-29`, with roles `customer` and `vendor` |
| Service catalogue with a fixed set of 6 categories | `Server/src/models/Service.js:20-27` (Cleaning, Repair, Salon, Electrician, Plumber, Cooking) |
| Bookings with a vendor-driven lifecycle | `Server/src/models/Booking.js:19-23` and `Server/src/controllers/bookingController.js:130-136` |
| Reviews allowed only after a completed booking | `Server/src/controllers/reviewController.js:12-23` |
| Geospatial intent (a "near me" feature) | 2dsphere indexes on User, Service and Booking, plus `GET /api/services/nearby` (`serviceController.js:232`) |
| Indian market | Prices shown in ₹, `wa.me/91…` links (`CustomerDashboard.jsx:356`), default coordinates in Noida/Delhi (`Signup.jsx:155`), `en-IN` date formatting |
| Off-platform contact | A WhatsApp number stored on each service (`Service.js:56`) |
| No payments | No payment model, gateway or SDK exists. `totalPrice` is copied from `service.price` (`bookingController.js:35`) |
| Branding | "VENY." with the taglines "The Elite Marketplace" and "Professional Marketplace", in a "cosmic/galaxy" copy theme |

### Value proposition (as the code implies it)
- **Customers** can browse services, see vendor ratings, book a slot without paying online, and track status with in-app and email notifications.
- **Vendors** can publish up to 4-image listings, receive bookings, run each job through confirm → start → complete, see revenue and a 6-month earnings chart, and pause listings.

### Deployment (from commit messages and code comments)
- The API is hosted on **Render**: `app.set('trust proxy', 1)` with the comment "Render ke liye" (`Server/src/index.js:15-16`), and the commit history includes Render networking fixes.
- The SPA is hosted on **Vercel**, with an SPA rewrite in `Client/veny-frontend/vercel.json`.
- Whether a live production deployment with real users exists is **Requires Verification**.

## Identified product gaps
These are confirmed absences, not recommendations.
- There is no administrator or moderation role, so nobody can remove bad vendors, listings or reviews.
- There is no password reset or "forgot password" flow.
- There is no payment, invoice or commission mechanism. UI copy such as "Secure Transaction via Veny Signal" (`ServiceDetail.jsx:229`) implies one exists.
- Vendor verification doesn't exist, although the UI shows "Verified Provider" (`ServiceDetail.jsx:179`).
- Users can't change their location or address after signup (`profileController.js:23` only accepts name, businessName and phoneNumber).
- There is no customer ↔ vendor messaging inside the platform. Contact happens only through WhatsApp, and that link is broken (see BUG-05).
- There is no vendor availability or calendar, so a customer can request any future datetime.
- The "near me" API exists, but the UI never uses it.
- Search is a client-side filter over only the first 10 results (BUG-04).

## Open questions for the product owner
1. Is a **commission or online-payment** model intended, or is Veny a lead-generation and booking tool only?
2. Is an **admin / moderation** role intended? This affects the auth model and the dashboard design.
3. Is the product **India-only**? This decides the currency, the phone format and the default map center.
4. Should categories stay **fixed in code**, or become admin-managed data?
5. Is there a **live deployment with real users or data**? This decides whether a migration strategy is needed.
6. Should vendors define **service areas or radii**, and should customers see distance?
7. Which email provider should be **canonical**: Resend (server-side) or EmailJS (browser-side)?
8. Who is the target audience? The answer decides the visual direction: premium/"elite" (current copy) or mass-market/trust-first.

## Proposed future (not implemented)
See [../planning/REDESIGN_ROADMAP.md](../planning/REDESIGN_ROADMAP.md). Product recommendations there are kept separate from features that already exist.
