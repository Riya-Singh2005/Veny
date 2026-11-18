# Design System: historical proposal

> **Superseded on 2026-11-19.** The implemented system is *Bombay Deco Nights*. See the repo-root `DESIGN.md`, the tokens in `src/styles/globals.css` and the live style guide at `/design`. This file is kept as the original proposal.

> **Status: proposal only. Nothing in this document is implemented.**
> The current UI is documented in [UI_UX_AUDIT.md](UI_UX_AUDIT.md).
> A **final visual direction has not been chosen.** It depends on open product questions, mainly the target audience (premium "elite" vs mass-market) and the market (India-only?). This document sets out a **foundation that works with either direction**, plus two candidate directions to choose between.

## 1. Design principles (proposed)
1. **Trust before flair.** A services marketplace sells reliability. Every claim shown must be backed by data (rating, verified status, completed jobs).
2. **Clarity over theme.** Plain verbs: Book, Cancel, Log out. Any theming goes in visuals, not in labels.
3. **One system, two portals.** Customer and vendor dashboards share one shell and one component set, with role-specific content.
4. **Accessible by default.** WCAG 2.2 AA: 4.5:1 text contrast, visible focus, labelled controls, reduced-motion support.
5. **Mobile-first.** Most home-service customers book from a phone.

## 2. Candidate visual directions (decision required)

| | A — "Evolved Night" | B — "Trusted Daylight" |
|---|---|---|
| Keeps | The current dark identity, indigo accent and wordmark | The wordmark and indigo as a brand accent |
| Changes | Drops the jargon, glow overload and 9px text; adds a light mode | Light-first with a dark mode; warm neutrals; photography-led cards |
| Fits | A premium, design-forward audience; the existing users' familiarity | A mass-market, trust-first local services audience |
| Risk | Dark-only UIs read as "tech product" rather than "home services" | A bigger visual change for existing users |

**Recommendation:** B fits a home-services marketplace better. The final choice should wait for answers on audience and market, so treat this as a recommendation, not a decision.

## 3. Foundation tokens

These are defined as CSS variables in Tailwind v4 `@theme`, which extends the existing `index.css` mechanism. Values are given for direction B, with dark-mode equivalents. Direction A would swap the neutral ramp.

### Colour (semantic)
| Token | Light | Dark | Use |
|---|---|---|---|
| `--color-bg` | `#FAFAF9` | `#0B0F19` | page |
| `--color-surface` | `#FFFFFF` | `#121826` | cards, modals |
| `--color-surface-2` | `#F4F4F5` | `#1A2131` | inputs, subtle fills |
| `--color-border` | `#E4E4E7` | `#273043` | dividers, inputs |
| `--color-text` | `#18181B` | `#F4F4F5` | primary text |
| `--color-text-muted` | `#52525B` | `#A1A1AA` | secondary text (≥4.5:1 on bg) |
| `--color-primary` | `#4F46E5` | `#818CF8` | brand, primary actions (keeps the indigo heritage) |
| `--color-primary-fg` | `#FFFFFF` | `#0B0F19` | text on primary |
| `--color-success` | `#15803D` | `#4ADE80` | completed, confirmed |
| `--color-warning` | `#B45309` | `#FBBF24` | pending |
| `--color-danger` | `#B91C1C` | `#F87171` | cancelled, destructive |
| `--color-info` | `#1D4ED8` | `#60A5FA` | in-progress |

Every pairing gets checked with a contrast tool before adoption, which happens in Phase 2.

### Booking status mapping (single source)
`pending → warning`, `confirmed → info`, `in-progress → primary`, `completed → success`, `cancelled → danger`. Each badge pairs the colour with an icon **and** a text label, so the status never relies on colour alone.

### Typography
- **Family:** one variable sans. Candidates are *Inter* or *Plus Jakarta Sans*. Use `font-display: swap`, self-hosted or from Google Fonts.
- **Scale:** rem-based, with a 14px minimum for UI text and 12px only for captions:

| Token | Size / line height | Weight | Use |
|---|---|---|---|
| `display` | 48/56 (clamp 36→56) | 700 | marketing hero |
| `h1` | 32/40 | 700 | page title |
| `h2` | 24/32 | 600 | section |
| `h3` | 20/28 | 600 | card title |
| `body` | 16/24 | 400 | default |
| `body-sm` | 14/20 | 400–500 | dense UI, table cells |
| `caption` | 12/16 | 500 | meta, timestamps |

- Uppercase is reserved for overline labels at 12px with `tracking-wide`. Italic is only for emphasis.

### Spacing
A 4px base: `0, 1(4), 2(8), 3(12), 4(16), 5(20), 6(24), 8(32), 10(40), 12(48), 16(64)`. This is the Tailwind default scale, used with discipline. Card padding is 16 on mobile and 24 from `md`. Section gaps are 32 or 48.

### Radius
Three values replace the current nine:
- `--radius-sm` 8px for inputs, chips and small buttons
- `--radius-md` 12px for buttons and cards
- `--radius-lg` 20px for modals, sheets and hero media
- `full` for avatars, badges and pills

### Elevation
- `shadow-sm`: `0 1px 2px rgb(0 0 0 / .06)` for inputs and cards at rest
- `shadow-md`: `0 4px 12px rgb(0 0 0 / .08)` for hovered cards and dropdowns
- `shadow-lg`: `0 12px 32px rgb(0 0 0 / .12)` for modals

In dark mode, elevation comes from a lighter surface rather than glows.

### Layout grid
- Container max width 1200px, gutters 16 / 24 / 32 at the sm / md / lg breakpoints.
- 4 columns on mobile, 8 on tablet, 12 on desktop.
- Dashboard: sidebar 256px (collapsible to 72px) with fluid content and a content max width of 1200px.

### Breakpoints
Tailwind defaults: `sm 640`, `md 768`, `lg 1024`, `xl 1280`. See [RESPONSIVE_DESIGN.md](RESPONSIVE_DESIGN.md).

### Motion
- Durations 150, 200 and 300ms. Easing `cubic-bezier(.2,.8,.2,1)`.
- No infinite decorative animation. All motion is wrapped in `motion-safe:`.

### Iconography
`lucide-react` (already installed), at 16px and 20px with a 1.75 stroke. Lucide icons replace emoji as status and notification icons.

## 4. Component system

| Component | Variants / states | Accessibility requirements | Replaces (current) |
|---|---|---|---|
| **Button** | primary, secondary, ghost, danger, link · sm/md/lg · loading, disabled · icon-left, icon-only | `<button>`, visible focus ring, icon-only needs `aria-label`, keeps its width while loading | `components/Button.jsx` + ~40 ad-hoc buttons |
| **Input / Textarea** | default, error, disabled · leading icon · helper text · character counter | `<label htmlFor>`, `aria-invalid`, `aria-describedby` for errors | inline inputs in every form |
| **Select / Dropdown** | native select (mobile), custom listbox (desktop) | WAI-ARIA listbox pattern | `AddServiceForm` select |
| **DateTime picker** | date + time slot | keyboard operable | `datetime-local` |
| **Modal / Sheet** | dialog (md+), bottom sheet (mobile), confirm dialog | focus trap, Esc closes, `role="dialog"`, `aria-modal`, scroll lock, focus returns on close | `BookingModal`, `AddressModal`, `window.confirm` |
| **Card** | service card, stat card, booking card, review card | whole-card link with a single focusable target | 2× `StatCard`, `ServiceCard` |
| **Badge** | status (5), category, "New", verified | text + icon | `STATUS_STYLES` ×2 |
| **Table / List** | responsive table (desktop) that collapses to cards (mobile) · sortable · empty · loading rows | `<table>` semantics on desktop | booking card lists |
| **Navigation** | public top bar (auth-aware), dashboard sidebar, mobile bottom tabs, breadcrumb | `<nav aria-label>`, `aria-current` | `Navbar`, two sidebars |
| **Dashboard widgets** | KPI stat, chart card, map card, recent activity list | charts get a text summary | inline in the dashboards |
| **Alert / Banner** | info, success, warning, danger · dismissible | `role="status"` or `alert` | inline error divs |
| **Toast** | success, error, info (keep `react-hot-toast`, restyled) | `aria-live` | current Toaster |
| **Notification panel** | popover (desktop), full sheet (mobile) · unread state · grouped by day | `aria-expanded`, list semantics | `NotificationBell` |
| **Loading** | spinner (inline), skeletons (cards, lists, detail) | `aria-busy` | themed spinners |
| **Empty state** | icon, title, description, primary action | — | existing empties, standardised |
| **Rating** | display (half stars), input (radio group) | radio group semantics | `StarRating` |
| **Avatar** | image, initials fallback · sizes | `alt` | repeated inline |
| **Image gallery / uploader** | carousel + thumbnails · drag-drop upload, reorder, remove | keyboard arrows, labelled controls | `ImageGallery`, `AddServiceForm` images |

### Implementation note (added 2026-11-17)
If ADR-010 is approved ([../planning/DECISIONS.md](../planning/DECISIONS.md)), these components would be built on **shadcn/ui** (Radix primitives) and themed with the tokens in §3:

| Component in the table above | shadcn/ui building block |
|---|---|
| Modal / Sheet | `Dialog`, `Sheet`, `AlertDialog` (replaces `window.confirm`) |
| Toast | `Sonner` |
| Select / Dropdown | `Select`, `DropdownMenu`, `Command` |
| Notification panel | `Popover` (desktop), `Sheet` (mobile) |
| Forms | `Form`, which wires up RHF and gives labelled, `aria-describedby` errors |
| Badge, Card, Table, Skeleton, Avatar, Tabs | Their direct equivalents |

`DatePicker` uses `Calendar` + `Popover`. `Rating` and `ImageManager` are custom.

## 5. Experience guidelines

### Customer
- Explore: search by keyword, filter by category, price and distance ("near me" uses the existing `/nearby` API), with paginated results or infinite scroll.
- Service detail: real trust signals only (rating, number of reviews, jobs completed, member since). The vendor profile is one tap away.
- Booking: date + time slot → address (saved list or edit) → notes → review → submit. Logged-out users are sent to login and returned to the booking afterwards.
- Bookings: a status timeline, contact-vendor actions and a cancel option with a reason.

### Vendor
- An onboarding checklist: profile, location, first listing, contact number.
- Bookings as an inbox with "Needs action" first. One-tap confirm, start and complete, with a confirmation for destructive actions.
- Listings: drafts, pause, and per-image management.
- Insights: completed jobs, notional earnings labelled as such until payments exist, and rating trend.

### Admin (only if the product owner approves an admin role)
- Users, vendors (verification queue), listings, reviews (moderation) and bookings (disputes), all in dense data tables.

### Forms
- Inline validation on blur, a summary at the top on submit, errors kept next to their fields, and the submit button disabled only while submitting.
- No placeholder-only labels.

### Dashboard usability
- Deep-linkable routes per section, with state kept across refreshes.
- KPIs at the top, then items that need action, then history.

### Accessibility checklist (gate for Phase 2)
- Contrast passes AA.
- Every interactive element is reachable with Tab and has a visible focus ring.
- Labels are associated with their inputs.
- Modals trap focus.
- `prefers-reduced-motion` is respected.
- Password managers work.
