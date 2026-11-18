# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
- **Customers (primary):** urban middle- and upper-class households in Indian metros (Delhi NCR, Bengaluru, Mumbai) who book trusted professionals for home services: cleaning, repair, salon, electrician, plumber, cooking. They book in short sessions, often on mobile, and care about trust, real availability and a calm, fast flow.
- **Vendors:** independent service professionals and small businesses. They list services, set weekly availability, verify their identity and run bookings (accept, reject, start, complete) from a dashboard, often on a phone between jobs.
- **Admins:** the Veny team. They verify vendors, moderate services and reviews, manage categories and monitor bookings.

## Product Purpose
Veny connects customers with **verified independent professionals** and lets them book a real, available time slot. Success means:
- a customer finds a verified pro and books a confirmed slot in a few minutes;
- vendors fill their calendars without double bookings;
- admins keep the marketplace trustworthy.

## Positioning
**Verified independent pros.** Every vendor is verified by an admin before they can be seen or booked. Customers book the professional directly, see their real availability, and pay them on-site with no platform markup. Tagline kept from the original brand: **"The Elite Marketplace"**.

## Operating Context
- India-only. Prices are in ₹ (stored in paise), with `en-IN` formatting and the Asia/Kolkata timezone by default.
- Booking flow: choose a service, pick an available slot (from the vendor's weekly hours and time off; one booking at a time per vendor), choose an address, then confirm. Status moves pending → confirmed / rejected / cancelled → in progress → completed, and a review can follow.
- Customers may cancel a confirmed booking until 2 hours before the start.
- Notifications are in-app (realtime) plus email.
- There are no online payments. Payment happens on-site, off-platform.

## Capabilities and Constraints
- SPA: React + Vite + Tailwind 4 + shadcn/ui on Supabase. Deployed on Vercel.
- Three role areas: public/customer, vendor dashboard and admin console.
- Minimal motion: 150–250 ms state transitions only. No scroll-jacking or GSAP in the app.
- **Undecided:** complaints/reports scope (to settle at M6); payments are out of scope for now.
- A separate **marketing website** is planned later, with its own references (see Brand Commitments).

## Brand Commitments
- **Name:** Veny.
- **Tagline:** "The Elite Marketplace".
- **Purple accent:** a violet/indigo stays the brand colour.
- **Dark-first UI:** dark is the default theme. A light theme is still allowed.
- **Rejected from the old app:** the "cosmic/galaxy" copy voice ("Initiate Mission", "Scan Galaxy", …), glow blobs and glassmorphism. They are anti-references.
- **References for the upcoming marketing site:**
  - https://two26.studio/ : confident, large stacked display type and generous section spacing.
  - https://www.cartier.com/en-fr/lechoeurdespierres : restrained, ceremonial and precise luxury.
  - Use them for mood only. Never copy their marks, names or copy.

## Evidence on Hand
- There are no real customer testimonials, ratings, press coverage or usage numbers. Never fabricate any of them.
- The 6 categories exist in the database.
- Seed data is for development only.
- The Veny logo needs to be designed; the old one was only a text wordmark.

## Product Principles
1. **Trust is visible:** verification status, real availability and real reviews are shown plainly. No unbacked claims.
2. **Premium means calm and precise,** not loud: restraint, clear hierarchy, careful detail.
3. **Booking is fast on a phone:** the customer flow is mobile-first.
4. **Plain language:** say "Book", "Cancel" and "Log out". No themed jargon.

## Accessibility & Inclusion
- WCAG 2.2 AA: contrast of at least 4.5:1 for body text (critical on a dark-first UI), labelled form fields, keyboard access everywhere and visible focus.
- `prefers-reduced-motion` is respected.
