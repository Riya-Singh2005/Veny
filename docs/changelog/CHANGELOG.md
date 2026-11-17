# Changelog

This file follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. It records changes to documentation and to the codebase, starting from the 2026-11-17 audit baseline.

## [Unreleased]

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
