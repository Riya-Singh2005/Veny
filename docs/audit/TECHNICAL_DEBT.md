# Technical Debt

Debt is grouped by how it was taken on, with a rough cost to repay: **S** is under 1 day, **M** is 1–3 days, **L** is more than 3 days.

## 1. Architectural debt
| Item | Cost | Notes |
|---|---|---|
| No service layer; fat controllers | M | Blocks unit testing of the business rules |
| Split email architecture (EmailJS client + Resend server) | S–M | Root cause of SEC-01. Resend is already wired in, so it needs consolidating plus a verified domain |
| Auth state in localStorage, read ad hoc | M | Needs an AuthProvider and a `/me` endpoint |
| No shared constants (categories, statuses, roles) across tiers | S | Three copies each |
| Inconsistent API envelope | M | Changing it touches every endpoint and the client parsing |
| App/listen not separated; no env validation | S | Prerequisite for API tests |

## 2. Code-level debt
| Item | Cost | Notes |
|---|---|---|
| Duplicated dashboards (~800 lines) | M | Merge into a shared layout and widgets |
| Oversized components (Signup, AddServiceForm, ServiceDetail, ReviewSection) | M | Split during the design-system migration |
| Ad-hoc styling with raw hex values and arbitrary radii | L | Repaid by the Phase 2 design system |
| Undefined animation utilities | S | Add a plugin or delete the classes |
| No-op try/catch wrappers in `serviceService` | S | — |
| Hinglish comments and "Bug N Fixed" markers that refer to a missing list | S | — |
| Three OTP generators | S | One helper |

## 3. Dependency debt
| Item | Cost | Notes |
|---|---|---|
| Unused: `@reduxjs/toolkit`, `react-redux`, `nodemailer` ×2, root `axios` | S | Remove after approval |
| `cloudinary@1` tied to `multer-storage-cloudinary@4` | M | Upgrading needs either a custom multer storage engine (multer memoryStorage + `upload_stream`) or a direct signed upload from the client |
| `validator` used for a single email check | S | Replace with Zod later |
| `@types/*` installed without TypeScript | — | Harmless, keep if TS is adopted |

## 4. Process debt
| Item | Cost | Notes |
|---|---|---|
| Zero automated tests | L | The biggest risk for any refactor |
| No CI | S | GitHub Actions running lint, test and build |
| No formatter or server lint | S | Prettier and ESLint |
| No README, `.env.example`, `engines` or setup instructions | S | Onboarding friction |
| Branch naming: local `dev` tracks remote `main` | S | Clarify the branching strategy |
| No error monitoring (e.g. Sentry) | S | — |

## 5. Data debt (needs production data inspection, V-08)
| Item | Notes |
|---|---|
| Users with Noida default coordinates | Unknown count. A migration needs a "please confirm your location" prompt |
| Users without an address | All of them, because of BUG-02 |
| Accounts "verified" while SEC-01 existed | All existing accounts. Decide whether they must re-verify |
| Orphaned bookings and reviews from deleted services | Unknown |
| Bookings with address `"Home"` | All of them |

## Repayment strategy
Debt is repaid **inside the roadmap phases**, not as a separate project:
- Security and correctness debt goes into Phase 1.
- Styling and duplication go into Phase 2/3.
- API and data debt go into Phase 4.
- Process debt goes into Phases 1 and 5.

See [../planning/REDESIGN_ROADMAP.md](../planning/REDESIGN_ROADMAP.md).
