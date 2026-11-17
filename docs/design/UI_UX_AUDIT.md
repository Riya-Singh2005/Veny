# UI / UX Audit

Method: static reading of JSX and CSS. The app was **not run**, so visual rendering, real contrast ratios and interaction feel are partly **Requires Verification**.

## Current implementation

### Visual identity
- **Theme:** "cosmic / galaxy" dark-only UI. The background is `#020617` (slate-950), the primary colour is indigo `#6366f1`, with blurred indigo "nebula" blobs, glassmorphism cards (`bg-white/5 backdrop-blur`) and a stardust texture loaded from an external site (`Login.jsx:72`, `VerifyOTP.jsx:71`).
- **Wordmark:** "VENY." in heavy black italic with an indigo full stop (`Navbar.jsx:25-27`).
- **Copy voice:** space metaphors throughout: "Explore Galaxy", "Scan Galaxy", "Initiate Mission", "Terminal Exit", "Exit Orbit", "Syncing with Stars", "Cosmic clearance required", "/ Per Mission", "Deploy Service", "Transmission failed". The taglines "The Elite Marketplace" and "Professional Marketplace" contradict each other.
- **Tokens:** `index.css:3-36` defines `--color-veny-{bg, primary, secondary, accent, card, dark, success, error, border}`. In practice only `veny-primary` is used. `secondary` and `accent` are never used, and raw hex values appear 25 times in JSX.

### Typography
- One font: `font-family: sans-serif` (`index.css:49`), which is the system default with no brand typeface.
- Heavy use of tiny uppercase tracking-wide labels: `text-[10px]` ×84, `text-[11px]` ×23, `text-[9px]` ×13, `text-[8px]` ×2. That's **122** sub-12px text instances, usually `font-black uppercase tracking-[0.2em+]`.
- Headings are `font-black italic tracking-tighter` almost everywhere, so hierarchy comes from size alone.

### Colour & contrast
- `text-gray-600` (×27) and `text-gray-700` (×17) on `#020617` backgrounds. Tailwind's gray-600 on slate-950 is roughly 3:1, and gray-700 is roughly 2:1. Both are **below WCAG AA (4.5:1)** for body text. They're used for helper text, labels and empty-state copy. Exact ratios are Requires Verification, because the v4 palette is OKLCH-based.
- Status colours use yellow, blue, indigo, green and red at 10% opacity backgrounds. That's acceptable, but the mapping is duplicated in `VendorDashboard.jsx:19` and `CustomerDashboard.jsx:16`.

### Shape & spacing
- The border radius is chaotic. There are 9 distinct values: `rounded-2xl` ×62, `rounded-full` ×47, `rounded-xl` ×22, `rounded-[2rem]` ×17, `rounded-[3rem]` ×11, `rounded-[2.5rem]` ×10, `rounded-[1.5rem]` ×6, `rounded-[1.8rem]` ×5 and `rounded-3xl` ×2.
- Spacing uses Tailwind defaults with no evident scale discipline. Card padding varies between `p-4`, `p-6`, `p-8`, `p-10` and `p-12`.
- Shadows are custom glow shadows, `shadow-[0_0_30px_rgba(...)]`, written inline per element.

### Components (as they exist)
| Element | Current state |
|---|---|
| Button | One primitive (`components/Button.jsx`), always `w-full`, always uppercase. It **ignores the `className` prop** callers pass. The loading label is always "Syncing...". Most buttons in the app are hand-rolled `<button>` elements with long class strings instead of this component |
| Inputs | Icon-left glass inputs, re-declared in every form. Signup uses an `inputClass` const in its modal but inline strings elsewhere |
| Modals | `BookingModal` and `AddressModal`: fixed overlays with no focus trap, no Esc to close, no `role="dialog"` or `aria-modal`, and no scroll lock |
| Cards | Service card, stat cards (2 different `StatCard` implementations) and booking cards |
| Tables | None. Bookings are card lists |
| Navigation | Public: a fixed top Navbar. Dashboard: a left sidebar with a mobile drawer. They're two separate navigation systems with no shared shell |
| Notifications | A bell dropdown in the dashboard header, with emoji type icons |
| Toasts | `react-hot-toast`, dark-styled (`App.jsx:27-34`) |
| Confirmations | `window.confirm` ×3 (`ReviewSection.jsx:99`, `CustomerDashboard.jsx:50`, `VendorDashboard.jsx:58`) |
| Loading | Spinners with themed copy. No skeletons |
| Empty states | Present for services, bookings, reviews and notifications |

### Accessibility
| Check | Finding |
|---|---|
| Form labels | `htmlFor` count = **0**. Labels aren't associated with inputs. Login and Signup rely on placeholders for some fields |
| ARIA | Only one `aria-*` attribute in all JSX (`Navbar.jsx:57`, `aria-label="Toggle menu"`) |
| Icon-only buttons | Notification bell, close (X), edit, delete and carousel arrows have no accessible names (`title` is on some) |
| Clickable divs | Sidebar logo (`VendorDashboard.jsx:143`) and notification rows (`NotificationBell.jsx:166`) are `div`s with `onClick`, so they aren't keyboard-reachable |
| Autocomplete | `autoComplete="new-password"` on the **email** field and on the login password (`Login.jsx:100,118`), plus hidden decoy inputs. This deliberately defeats password managers |
| Focus styles | Inputs have focus borders. Buttons rely on browser defaults, or have none |
| Motion | Infinite blob, ping and pulse animations with no `prefers-reduced-motion` handling |
| Language | `<html lang="en">` is set. The `<title>` is `veny-frontend` (`index.html:7`) |
| Images | Service images use `alt={service.name}`. The gallery uses `alt="service-0"`, review avatars use `alt=""` |

### Usability problems
1. **Navbar isn't aware of auth state.** Logged-in users still see Login and Signup, and there's no link back to the dashboard (`Navbar.jsx:13-17`).
2. The **"Join as Vendor"** CTA opens signup on the *customer* role.
3. **Explore shows at most 10 services** (BUG-04), with no pagination or "load more".
4. The hero **"Scan Galaxy" button does nothing**, and the dashboard search inputs do nothing.
5. **A guest who tries to book** gets a toast and the modal closes. There's no redirect to login and no return afterwards.
6. **Refreshing `/verify-otp`** throws the user back to `/login`.
7. **Dashboard sections aren't URLs**: refresh resets to Overview and Back leaves the dashboard.
8. Booking only accepts a date and time. There's no address choice, notes field or slot availability, and the address shown is always "Home".
9. **Misleading copy:** "Verified Provider", "Instant Booking – Zero Wait Time", "Secure Transaction via Veny Signal", "Avg. 2 Hours" and "All Systems Operational" aren't backed by any feature.
10. Themed jargon hurts clarity. "Initiate Mission" means Book, "Terminal Exit" means Log out, "Security Key" means Password.
11. Every footer link goes to `#`.
12. Password managers are blocked on login.
13. Error messages render as `uppercase italic tracking-tighter` 11px red text, which is hard to read.
14. A vendor's paused service can't be previewed.

## Identified problems summary
- UX-01: no design-system primitives; everything is inline.
- UX-02: inconsistent radius, type and spacing.
- UX-03: contrast failures.
- UX-04: missing labels and ARIA.
- UX-05: modal accessibility.
- UX-06: auth-unaware navigation.
- UX-07: misleading claims.
- UX-08: jargon copy.
- UX-09: no reduced-motion handling.
- UX-10: password manager suppression.
- UX-11: undefined animation classes (FE-06).

## Strengths worth keeping
- A coherent dark aesthetic with a recognisable wordmark.
- Consistent status-colour semantics.
- Empty and loading states exist on most views.
- A mobile drawer exists for the dashboards.
- A good base flow: browse → detail → book → status → review.

See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for the proposed direction.
