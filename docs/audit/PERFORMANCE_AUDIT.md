# Performance Audit

No profiling, build or Lighthouse run was performed, because the audit was static-only. Problems that the code proves are listed separately from theoretical optimisations.

## Actual problems (confirmed from code)

| ID | Area | Problem | Evidence | Impact |
|---|---|---|---|---|
| PERF-01 | API | Email is sent synchronously in the booking create and status-update handlers | `bookingController.js:48,185`; `notificationController.js:13-18` | Each booking action waits for a Resend round-trip |
| PERF-02 | API/DB | Unbounded list endpoints: `my-bookings` (3 populates), `reviews/service/:id`, `/nearby`, and `GET /services` with an uncapped `limit` | `bookingController.js:76`; `reviewController.js:58`; `serviceController.js:198,240` | The response size and the populate fan-out grow linearly with data |
| PERF-03 | Client/API | Notification polling every 30s × 2 queries (`find` + `countDocuments`) per open dashboard tab, sharing the 100/15-min rate limit | `NotificationBell.jsx:40`; `notificationController.js:30-37` | 60 requests/hour/tab of background load, which can trigger 429s for the user |
| PERF-04 | DB | `search` uses an unanchored, case-insensitive `$regex` | `serviceController.js:193` | Collection scan on every search, plus ReDoS potential |
| PERF-05 | DB | `GET /services` runs `countDocuments` and `find` separately and uses skip pagination | `serviceController.js:200-205` | Fine at small scale; degrades with deep pages |
| PERF-06 | DB | Missing indexes for actual queries: `services.vendor`, `bookings` sorted by `createdAt` per user, the `reviews` + `bookings` lookup `{service, customer, status}` | see `DATABASE_ARCHITECTURE.md` | In-memory sorts and scans as data grows |
| PERF-07 | Client | No code splitting: Leaflet, Recharts and both dashboards are bundled into the entry chunk for all visitors, including anonymous Explore users | `App.jsx:4-12` (static imports) | Larger first load. The exact size is V-02 |
| PERF-08 | Client | Explore fetches data once and filters in memory. Logic is fine but it's tied to BUG-04 | `AllServices.jsx:146-176` | Correctness issue more than speed |
| PERF-09 | Client | Heavy GPU effects: multiple 450–500px `blur-[120px]` elements, `backdrop-blur-2xl/3xl`, infinite `animate-blob`/`ping`/`pulse` | `Login.jsx:70-71`, dashboards, `AllServices.jsx` hero | Likely jank and battery drain on low-end Android (V-09) |
| PERF-10 | Client | Images: Cloudinary URLs are used as delivered (`file.path`) without `f_auto,q_auto` or responsive `srcset`; no `loading="lazy"` on card images | `AllServices.jsx:72-76`; `ServiceDetail.jsx:27-31` | Larger images than needed. The 800×600 crop at upload is good |
| PERF-11 | Client | Object URLs created for previews are never revoked | `AddServiceForm.jsx:62`; `ProfileSettings.jsx:30` | Minor memory leak per selection |
| PERF-12 | Client | Re-fetching the full lists after every mutation (`fetchServices()` and `fetchBookings()` after each toggle or status change) | `VendorDashboard.jsx:62,72,81` | Extra round-trips; no optimistic UI |
| PERF-13 | Client | An external background image from `transparenttextures.com` on auth pages | `Login.jsx:72` | Extra third-party DNS lookup and request on the critical auth path |
| PERF-14 | API | `Review` post-save hook aggregate on every review; not awaited | `Review.js:44-50` | Fine at this scale; noted for correctness, not speed |

## Theoretical opportunities (not current problems)
- HTTP caching (`Cache-Control`, ETag) on public `GET /services` and `/services/:id`.
- Response compression (`compression` middleware), unless Render handles it at the edge (V).
- `.lean()` on read-only queries. It's already used in `getMyServices`.
- Replace polling with SSE or WebSockets once real-time requirements are clear.
- TanStack Query caching would remove the duplicate fetches across dashboard tabs.
- Atlas Search or a text index for relevance-ranked search.
- Preconnect to Cloudinary and CARTO origins.
- Memoisation (`useMemo` for `earningsData` and the filtered lists). The current computations are trivial, so this is **not needed now**.

## Unnecessary re-renders
No confirmed hotspots were found. The components are small and the state is local. The dashboards recompute derived stats on every render (`VendorDashboard.jsx:100-119`), which is negligible at current list sizes.

## Recommended verification (Phase 5)
- `vite build` with `rollup-plugin-visualizer` for bundle composition.
- Lighthouse mobile on `/explore` and `/service/:id`.
- `explain()` for each query listed in DATABASE_ARCHITECTURE.md against a seeded dataset.
- A k6 or autocannon load test of `GET /api/services` and booking creation.
