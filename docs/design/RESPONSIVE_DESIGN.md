# Responsive Design

## Current implementation

- Tailwind default breakpoints are used, with no custom ones: `sm` 640px ×8, `md` 768px ×30, `lg` 1024px ×10. There are no `xl` or `2xl` usages.
- The approach is mobile-first: base classes plus `md:` and `lg:` overrides.
- The viewport meta tag is present (`index.html:6`).

### Per-view behaviour (from classes)

| View | Mobile (<768) | Tablet (md) | Desktop (lg) | Source |
|---|---|---|---|---|
| Navbar | Logo, the "Join as Vendor" CTA and a hamburger with a dropdown | Inline links | Same as md | `Navbar.jsx:33,54,65` |
| Explore grid | 1 column | 2 columns | 3 columns | `AllServices.jsx:209` |
| Explore hero | Heading `text-6xl` (60px) | `md:text-9xl` (128px) | Same | `AllServices.jsx:27` |
| Service detail | Stacked | Stacked (image `md:h-96`) | 2 columns | `ServiceDetail.jsx:136` |
| Login / Signup card | `p-8`, full width up to `max-w-md` / `max-w-lg` | `p-12` | Same | `Login.jsx:74`, `Signup.jsx:282` |
| Signup password row | 1 column | 2 columns | | `Signup.jsx:356` |
| Dashboard sidebar | Off-canvas drawer, `fixed -left-72` toggled to `left-0`, with a backdrop | `md:sticky md:left-0`, always visible at 288px | Same | `VendorDashboard.jsx:137,141` |
| Dashboard stats | 1 column | `sm:` 2 columns | `lg:` 4 columns | `VendorDashboard.jsx`, `CustomerDashboard.jsx` |
| Dashboard map + side panel | Stacked | Stacked | 12-column grid (8/4 vendor, 7/5 customer) | same |
| Notification dropdown | Fixed `w-80` (320px), absolutely positioned on the right | | | `NotificationBell.jsx:121` |
| Footer | 1 column | 4 columns | | `Footer.jsx:14` |

## Identified problems
| ID | Problem | Evidence | Severity |
|---|---|---|---|
| RWD-01 | A permanent 288px sidebar at 768px leaves about 480px for content on tablets. Collapsing it to icons, or using a drawer until `lg`, would fit better | `VendorDashboard.jsx:141` | Medium |
| RWD-02 | The notification dropdown is a fixed 320px from the right edge. On 320–360px phones it can overflow the left edge (Requires Verification) | `NotificationBell.jsx:121` | Medium |
| RWD-03 | Large decorative blurred blobs of 450–500px, plus `backdrop-blur-2xl/3xl`, are expensive on low-end mobile GPUs. Scroll jank is Requires Verification | `Login.jsx:70-71`, `CustomerDashboard.jsx:110-111` | Medium |
| RWD-04 | Cards use oversized radii (`rounded-[3rem]`) and `p-8` on mobile, which wastes horizontal space at 360px | `Login.jsx:74` | Low |
| RWD-05 | Tap targets: icon buttons at `p-1.5` with 15px icons (the notification header) are about 27px, below the 44px guideline | `NotificationBell.jsx:135-152` | Medium |
| RWD-06 | The Explore category chips wrap onto multiple centered rows on mobile instead of scrolling horizontally | `AllServices.jsx:184` | Low |
| RWD-07 | The map has a fixed `h-[360px]` and `scrollWheelZoom={false}`, but touch drag inside a scrolling page can trap the scroll | `CustomerDashboard.jsx:221`, `Map.jsx:39` | Low |
| RWD-08 | Modals have no max-height or overflow handling. `AddressModal` on short or landscape screens may be clipped | `Signup.jsx:42-43` | Medium |
| RWD-09 | No mobile bottom navigation for the dashboards. Every section switch needs the drawer opened first | dashboards | Low |

Real-device and emulator checks were **not performed**. Every row above should be validated in Phase 5 (responsive testing).

## Proposed future (not implemented)
- Breakpoints: keep the Tailwind defaults and add `xs: 400px` only if it's needed.
- Shell:
  - Below `lg`: top app bar plus a bottom tab bar (4 items) for the dashboards.
  - `lg` and up: a collapsible sidebar (72px icons ↔ 256px expanded).
- Explore: sticky filter bar with horizontally scrolling chips on mobile, and a filter sheet for price and distance.
- Modals: full-screen sheet on mobile, centered dialog at `md` and up.
- Test matrix: 360×740, 390×844, 768×1024, 1024×768, 1440×900, plus a landscape phone. Test both with `prefers-reduced-motion` on.
