# Changelog

This file follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. It records changes to documentation and to the codebase, starting from the 2026-11-17 audit baseline.

## [Unreleased]

### Added: 2026-11-19 (M2 design system, "Bombay Deco Nights")
- **Product record:** `PRODUCT.md` at the repo root, from the owner's answers:
  - audience: urban middle/upper-class metro households;
  - positioning: verified independent pros;
  - kept: the name Veny, the purple accent, dark-first UI and "The Elite Marketplace";
  - marketing-site mood references: two26.studio and Cartier.
- **Visual direction chosen by the owner:** *Bombay Deco Nights*.
  - Ink-violet lacquer ground, brass hairline seams (no shadows), amethyst for primary actions only, ivory text.
  - Bodoni Moda display with Manrope UI. Both fonts are self-hosted via `@fontsource-variable`.
  - Signature: a stepped Deco frame around the slot picker.
  - Direction contract: `.impeccable/surfaces/src-app.md`. Decision sketches: `.impeccable/mocks/decision/`.
- **Tokens:** `src/styles/globals.css`, dark (default) and light, with WCAG AA contrast checked by axe.
- **Primitives:** `src/components/ui` (button, input/textarea/select, label, badge, skeleton/separator, dialog, tabs) on Radix.
- **Shared components:** Logo, VerifiedSeal, Rating, PriceTag, StatusBadge, PageHeader, EmptyState, Monogram, ServiceCover (honest no-photo placeholder), SlotPicker (ARIA radio group with arrow keys) and DecoFrame.
- **Layouts:**
  - `PublicLayout`: sticky header, mobile menu sheet, skip link, footer;
  - `DashboardLayout`: sidebar on desktop, bottom tabs on phones.
- **Home page on live data:**
  - categories;
  - newly verified services (`search_services`);
  - the earliest free slot across verified services over the next 7 days (`get_available_slots`).
- **Design previews with bannered sample data:** `/design` (style guide with a dark/light toggle), `/design/service` (service detail) and `/design/vendor` (vendor workspace).
- **Placeholder pages:** `/services`, `/services/:slug`, `/login` and `/signup` honestly say which milestone delivers them.
- **Tests:**
  - `src/lib/utils/time.test.ts`;
  - `tests/e2e/home.spec.ts` (replaces `foundation.spec.ts`);
  - `tests/e2e/a11y.spec.ts`: axe WCAG 2.2 AA on every screen, desktop and mobile, plus the light theme.
  - **17 unit and 20 E2E tests pass.**
- **Design review:** the impeccable finish review ran two rounds. All 8 material fixes were scored resolved, and one follow-up regression (an eyebrow label) was removed.
- **Removed:** the temporary M1 `FoundationPage`.
- **Known issues:**
  - The main JS bundle is 780 kB (229 kB gzipped). Route-level splitting is planned for M3/M4.
  - The location selector is deferred to M4, because it needs real geolocation.
  - The logo is an authored CSS/SVG mark. The brandkit board is deferred because no image generation is available.

### Added — 2026-11-18 (M1 foundation, React + Vite)
- **Decision ADR-020:** React + Vite + React Router SPA replaces Next.js (ADR-002 superseded). Also decided: PD-02 (verification required), one booking at a time per vendor, a 2 h customer cancellation window, vendor reject, and the app at the repo root.
- New app at the repo root:
  - `package.json` replaces the stray axios-only root manifest, with exact-pinned dependencies;
  - `vite.config.ts`, `tsconfig*.json` (strict), `eslint.config.js`, `playwright.config.ts`, `components.json`, `index.html`, `.env.example`;
  - the folder tree from the brief.
- `src/lib`:
  - `env.ts`: Zod-validated; rejects `sb_secret_` keys;
  - `supabase/client.ts`: typed, publishable key only;
  - `errors.ts`: SQLSTATE/HINT → `AppError`;
  - `utils`: `cn`, `formatPrice`.
- App shell: providers (TanStack Query, sonner), router with an error/not-found route, and a temporary foundation page that reads categories through RLS.
- Generated DB types moved to `src/types/database.types.ts`.
- Migrations:
  - `20261118000100_enum_values.sql`: `rejected` booking status and new notification types;
  - `20261118000200_marketplace.sql`: verification, availability, time off, slots, overlap constraint, reject, cancel window, favorites, `get_my_access`, verified-only visibility.
- Tests:
  - `supabase/tests/database/03_marketplace.test.sql` is new; tests 01 and 02 are updated for the new rules. **132 pgTAP assertions pass.**
  - 14 Vitest unit tests and 4 Playwright E2E tests (desktop + mobile) pass.
- CI: `.github/workflows/web.yml` (typecheck, lint, test, build, secret scan of the bundle); the database workflow's types path is updated.
- `CLAUDE.md` created.
- Docs: DECISIONS, FRONTEND_ARCHITECTURE Part C, DATABASE_ARCHITECTURE §0 (additions and the future payments design), IMPLEMENTATION_PLAN Part C.
- **Not done:** the new migrations aren't pushed to staging (🔐), and nothing is pushed to GitHub (🔐).

### Changed — 2026-11-17 (staging)
- Git branches: `dev` (work, deploys to the **staging** Supabase project) and `prod` (created at `d6f8147`; it will deploy to a separate production project once that exists). `dev` is promoted to `prod` by a PR after testing. CI runs on both branches.
- **Applied migrations `20261117000100`–`20261117000400` to the staging Supabase project** (`supabase db push`, approved by the product owner). The seed was not pushed.
- Hosted Security Advisor: 9 × WARN `authenticated_security_definer_function_executable`, for the intended RPCs (`create_booking`, `transition_booking`, `create_review`, `soft_delete_service`, `get_booking_contact`, `get_my_vendor` and the 3 `admin_*` functions). These are **accepted by design**: each one checks `auth.uid()` (and `is_admin()` for the admin RPCs) and none is executable by `anon`. 1 × INFO `rls_enabled_no_policy` on `admin_users`, which is intentional. Performance: 7 × WARN for multiple permissive policies (separate admin policies, kept for auditability).
- Types generated from staging match the local schema. The only differences are generator formatting and metadata.

### Added — 2026-11-17 (Phase 1: Supabase foundation, local only)
- Decisions: PD-04 = yes (vendor self-selection). The existing Supabase project is **staging**.
- `supabase/` initialized with Supabase CLI 2.107.0. Local ports moved to 553xx because another local project uses the defaults.
- Migrations:
  - `20261117000100_schema.sql`: PostGIS, enums, 12 tables, constraints and indexes; RLS enabled at creation; the 6 categories.
  - `20261117000200_functions.sql`: sign-up trigger, guards, booking, review, search, contact and notification RPCs, and admin RPCs with an audit log.
  - `20261117000300_rls_grants.sql`: all API privileges revoked, then explicit table and column grants, policies, and the Realtime publication.
  - `20261117000400_storage.sql`: the `service-images` and `avatars` buckets and their policies.
- `supabase/seed.sql`: local dev fixtures (2 customers, 2 vendors, 1 admin, bookings in every status). Local stack only.
- `supabase/tests/database/`: 92 pgTAP assertions, all passing (RLS negative tests, every booking transition, reviews and ratings, admin).
- `supabase/types/database.types.ts`: generated types.
- `.github/workflows/database.yml`: lint, tests, Security Advisor, types drift check.
- `supabase/config.toml` (local Auth): email confirmation required, 8-character passwords with letters and digits, TOTP MFA, redirect allow-list.
- Docs: DATABASE_ARCHITECTURE Part B §0 lists how the implementation differs from the design (private helper schema, column grants instead of views, `author_name`, `hidden_at`, `logo_path`, admin RPC names). RLS, API, backend, plan, roadmap and decisions docs updated.
- Verification: `db reset` is clean; lint finds no errors in `public` or `private`; the Security Advisor reports only one INFO (`admin_users` has no policies, which is intentional); an Auth and REST smoke test passed.
- **Not done:** nothing was applied to the staging project, and no application source (`Client/`, `Server/`) was changed.

### Decisions recorded — 2026-11-17 (product owner, second batch)
- PD-03: email + password with email confirmation required.
- PD-11: Pro plan for production; Free for development and staging.
- PD-12: same repo, with `apps/web/` and `supabase/` folders.
- PD-13: admin option (b): verify and suspend vendors, hide reviews and listings, view all bookings, cancel bookings from any non-terminal state, and manage categories. No role changes or impersonation.
- A Supabase project has been created by the product owner. Its URL and publishable key are deliberately **not** recorded in the docs. Env variable names were updated to the new key naming (`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`).
- Still open: PD-02, PD-04, PD-08, PD-09, PD-14, plus which environment the existing project is.

### Decisions recorded — 2026-11-17 (product owner)
- **Approved ADR-002 to ADR-019.** Status notes in the architecture, planning and technology docs now say Approved instead of awaiting approval. Nothing has been implemented.
- **PD-01: admin role, yes.**
  - `admin_users` and `is_admin()` are now required.
  - Added the admin policy pattern, an `admin_audit_log` table and the `set_vendor_status` RPC (RLS_AUTHORIZATION §4.3).
  - The admin console is in scope (roadmap 4.9; backlog item 32).
  - New pending questions: PD-13 (what admins can do) and PD-14 (how the first admin is created).
- **PD-06: no production data.**
  - Migration Phase 5 is removed, and MONGODB_TO_SUPABASE_MIGRATION.md is marked not required (kept for reference).
  - Phase 0b hotfix is marked not needed.
  - PD-05, PD-07 and PD-10 are moot.
  - ADR-019 no longer has any effect.
  - Removed from the proposed schema: the Cloudinary image-provider columns and enum, the `legacy_default` location source, and `legacy_id_map`.
  - New recommendation: take the old MERN deployment offline, because SEC-01 is still reachable while it is public (🔐 needs approval).

### Added — 2026-11-17 (Supabase + Next.js reassessment)
- `docs/planning/DECISIONS.md`: an architecture decision log.
  - ADR-001: Supabase PostgreSQL. **Approved.**
  - ADR-002 to ADR-019: recommended, awaiting approval.
  - PD-01 to PD-12: pending decisions.
- `docs/architecture/RLS_AUTHORIZATION.md`: the Supabase Auth model, RLS matrix and policy sketches, Storage and Realtime rules, the RLS test plan, and new risks.
- `docs/planning/MONGODB_TO_SUPABASE_MIGRATION.md`: source inventory, ID mapping, transformation rules, Cloudinary strategy, validation suite, cutover and rollback.

### Changed — 2026-11-17 (Supabase + Next.js reassessment)
- Architecture docs (`ARCHITECTURE`, `FRONTEND_ARCHITECTURE`, `BACKEND_ARCHITECTURE`, `DATABASE_ARCHITECTURE`, `API_DOCUMENTATION`) are restructured into Part A (current, unchanged) and Part B (target). Part B adds:
  - the PostgreSQL schema and ER diagram
  - the endpoint migration map
  - the Next.js route design
  - the plan to retire Express
- `TECHNOLOGY_RECOMMENDATIONS.md`: Part B gives a verdict on each item in the proposed stack.
- `REDESIGN_ROADMAP.md` and `IMPLEMENTATION_PLAN.md`: the MERN plans are marked superseded, and a new Part B roadmap and backlog are added.
- `audit/BUGS_AND_ISSUES.md`: adds a reassessment section that classifies every ID as ARCH, DESIGN, FIX, N/A or OPEN. The original rows are unchanged.
- `audit/TECHNICAL_AUDIT.md`: adds section E, the target architecture assessment.
- `design/DESIGN_SYSTEM.md`: adds a note mapping the components to shadcn/ui.
- `README.md`: adds the decision-status legend and index entries for the new files.
- Correction: the current API was previously described as having "22 endpoints". The actual count is **27 route handlers** plus the health check. Fixed in README and API_DOCUMENTATION Part B.
- No application source, configuration, dependency, schema or data changes. No Supabase project was created and no database was connected.

### Added — initial audit
- 2026-11-17: `docs/` created with the initial codebase audit, product discovery, architecture documentation, a proposed design system and a modernization roadmap. The audit baseline is commit `d6f8147` on branch `dev`.

### Changed
- None. No source code, configuration, dependency, schema or data changes have been made.
