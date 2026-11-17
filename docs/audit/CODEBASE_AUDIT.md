# Codebase Audit

## Current implementation

### Size
| Area | Files | Approx. lines |
|---|---|---|
| Server `src/` | 23 JS files (1 entry, 1 config, 3 middleware, 5 models, 6 routes, 6 controllers, 1 util) | 1,637 (controllers 945) |
| Client `src/` | 26 code files (10 components + 8 pages = 3,540 lines; App.jsx, main.jsx, 4 JS modules, 2 CSS) + 3 assets | ~3,800 |
| Tests | **0** | — |
| Docs (before this audit) | 1 (Vite boilerplate README) | — |

### Git
- Remote `origin` is `github.com/RiyaThakur20/Veny-Mern-FullStack`. Local branch `dev` tracks `origin/main`.
- 23 commits, 2026-05-13 → 2026-06-06.
- About half of the commits are deployment and email firefighting: Brevo SMTP → Brevo HTTP → Gmail IPv4 → Resend → EmailJS.
- The working tree was clean when the audit started.

### File inventory: used / unused / duplicate

**Verified unused (0 references found by grep):**
| File / dependency | Notes |
|---|---|
| `Client/veny-frontend/src/App.css` | Empty and not imported |
| `src/assets/hero.png`, `react.svg`, `vite.svg` | Vite template leftovers. `hero.png` is 45KB |
| `public/icons.svg` | Vite template sprite |
| `@reduxjs/toolkit`, `react-redux` | No imports |
| `nodemailer` (client dependency) | No imports. It's a Node-only library and doesn't belong in a browser app |
| `nodemailer` (server dependency) | No imports since the switch to Resend |
| Root `package.json` → `axios` | No code at the root |
| `authService.getProfile`, `serviceService.getNearbyServices`, `bookingService.updateStatus` | Defined but never called. VendorDashboard calls axios directly instead |
| `GET /api/auth/profile`, `POST /api/auth/add-service` | Test routes with no client caller |

`public/favicon.svg` **is used** (`index.html:5`). These files are listed only. **Nothing has been deleted.** Removing them needs approval.

**Duplicated logic:**
| Duplicate | Locations |
|---|---|
| Dashboard shell (blobs, sidebar, mobile drawer, header, avatar, logout) | `VendorDashboard.jsx:131-200` ≈ `CustomerDashboard.jsx:108-206` |
| `STATUS_STYLES` map | `VendorDashboard.jsx:19`, `CustomerDashboard.jsx:16` (they differ: the customer one has `label`) |
| `StatCard` component | `VendorDashboard.jsx:405`, `CustomerDashboard.jsx:394` (different APIs) |
| `userLocation` lat/lng swap with a fallback | `VendorDashboard.jsx:89`, `CustomerDashboard.jsx:85` |
| `handleLogout` | both dashboards |
| Categories array | `AllServices.jsx:144`, `AddServiceForm.jsx:6`, `models/Service.js:24` |
| Booking status list | `bookingController.js:6`, `models/Booking.js:21`, `CustomerDashboard.jsx:24` |
| OTP generation (3×) | `authController.js:33,80,155` |
| Auth page backgrounds (blobs + card) | `Login.jsx`, `Signup.jsx`, `VerifyOTP.jsx` |
| The `msg \|\| message` error-extraction pattern | 10+ call sites |
| Cloudinary image mapping `{url: file.path, public_id: file.filename}` | `serviceController.js:24,103`, `profileController.js:69` |

**Oversized components (above about 250 lines and mixing concerns):** `VendorDashboard` (414), `CustomerDashboard` (411), `Signup` (403), `AddServiceForm` (302), `ReviewSection` (270), `ServiceDetail` (250).

### Conventions observed
| Topic | State |
|---|---|
| Language | JavaScript only. Server is CommonJS, client is ESM |
| Formatting | No Prettier. Mixed 2- and 4-space indentation (Login.jsx uses 2, the rest use 4). Column-aligned assignments in places |
| Naming | Mostly consistent camelCase. Model name `'user'` is lowercase while the others are PascalCase |
| Comments | A mix of English and Hinglish, plus "✅ Bug N Fixed" markers that refer to an external bug list not present in the repo |
| Lint | ESLint flat config, client only. Nothing on the server |
| Commits | Partly conventional (`fix:`, `chore:`), partly free-form |

## Identified problems
Summarised here; details are in [BUGS_AND_ISSUES.md](BUGS_AND_ISSUES.md):
- Duplicated logic (FE-01).
- Unused dependencies and files (FE-08, FE-09).
- No tests.
- No formatter.
- No server lint.
- Undocumented "Bug N" markers.
- Constants that should be shared are hardcoded in three places.

## Proposed future (not implemented)
- A `shared/constants` module for categories, statuses and roles. These could be served by the API (`GET /meta`) so the client doesn't duplicate them.
- Prettier + ESLint on both apps, a `lint-staged` pre-commit hook and EditorConfig.
- npm workspaces at the root, with scripts `dev`, `lint`, `test` and `build` across both apps.
