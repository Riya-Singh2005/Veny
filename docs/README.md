# Veny — Project Documentation

> Audit baseline: branch `dev` (tracking `origin/main`), last commit `d6f8147` (2026-06-06).
> Audit date: 2026-11-17. Method: **static code inspection only**. No packages were installed, and nothing was built, linted, run or connected to a database.

This folder documents **what Veny is today**, **what is wrong with it**, and **a proposed path to modernize it**. Nothing in here has been implemented yet.

## How to read these docs

Every document keeps these four kinds of content apart:

| Section label | Meaning |
|---|---|
| **Current implementation** | What the code does today. It is backed by `file:line` references. |
| **Identified problems** | Defects and risks found in the current code. |
| **Proposed future** | Recommendations only. They are *not* implemented. |
| **Planned improvements** | Concrete tasks queued in the roadmap. They are *not* started. |

File paths are relative to the repository root (`Veny-Mern-FullStack/`).

### Decision status (added 2026-11-17)

On 2026-11-17 the product owner **approved replacing MongoDB with Supabase (PostgreSQL)**. A full Next.js + Supabase target architecture is now **proposed**.

Architecture and planning docs are split into two parts:
- **Part A** is the current MERN implementation, as audited.
- **Part B** is the target design.

| Class | Meaning | Where tracked |
|---|---|---|
| **Existing implementation** | The MERN code as it is today | "Part A" sections, the product docs, the audit docs |
| **Approved decision** | Decided by the product owner | [planning/DECISIONS.md](planning/DECISIONS.md): ADR-001 to ADR-019, PD-01 (admin role: yes) and PD-06 (no production data) |
| **Approved target architecture** | The designs in Part B, approved but not built yet | "Part B" sections and `RLS_AUTHORIZATION.md`. `MONGODB_TO_SUPABASE_MIGRATION.md` is **not required** (PD-06) and is kept for reference only |
| **Pending decision** | Needs a product-owner answer | DECISIONS.md, entries PD-01 to PD-12 |
| **Future implementation task** | Not started | [planning/IMPLEMENTATION_PLAN.md](planning/IMPLEMENTATION_PLAN.md), Part B |

**Start here for the rebuild:** [DECISIONS.md](planning/DECISIONS.md), then [ARCHITECTURE.md Part B](architecture/ARCHITECTURE.md), then [DATABASE_ARCHITECTURE.md Part B](architecture/DATABASE_ARCHITECTURE.md), then [RLS_AUTHORIZATION.md](architecture/RLS_AUTHORIZATION.md), then [REDESIGN_ROADMAP.md Part B](planning/REDESIGN_ROADMAP.md).

### Implementation status legend (used in FEATURES.md)

| Status | Meaning |
|---|---|
| Fully Implemented | Works end-to-end in the UI and the API, as far as static inspection can tell |
| Partially Implemented | Works, but parts of it are missing or wrong |
| UI Only | Exists in the frontend with no working backend behind it |
| Backend Only | API exists, but no UI uses it |
| Not Implemented | Absent, although implied by the UI, copy or schema |
| Broken or Incomplete | Present, but a confirmed defect stops it working as intended |
| Requires Verification | Can't be confirmed without running the app |

### Finding confidence

- **Confirmed**: proven by reading the code. A `file:line` reference is given.
- **Potential risk**: plausible from the code, but depends on runtime, configuration or data.
- **Requires Verification**: needs a running app, a build, or `npm audit`.

## Index

### product/
- [PRODUCT.md](product/PRODUCT.md): what Veny is, inferred from the code
- [FEATURES.md](product/FEATURES.md): feature inventory with status
- [USER_ROLES.md](product/USER_ROLES.md): roles and the permission matrix
- [USER_FLOWS.md](product/USER_FLOWS.md): end-to-end workflows (Mermaid)

### architecture/
- [ARCHITECTURE.md](architecture/ARCHITECTURE.md): system overview. Part A is the current setup (integrations, deployment). Part B is the target design, the stack reassessment and the split of responsibilities
- [FRONTEND_ARCHITECTURE.md](architecture/FRONTEND_ARCHITECTURE.md): Part A is the Vite SPA. Part B is Next.js App Router: routes, SEO and data fetching
- [BACKEND_ARCHITECTURE.md](architecture/BACKEND_ARCHITECTURE.md): Part A is Express. Part B explains why Express is retired and maps each controller to an RPC, Server Action or Edge Function
- [DATABASE_ARCHITECTURE.md](architecture/DATABASE_ARCHITECTURE.md): Part A is MongoDB. Part B is the **proposed PostgreSQL schema**, its functions and the ER diagram
- [API_DOCUMENTATION.md](architecture/API_DOCUMENTATION.md): Part A covers all 27 route handlers plus the health check, as implemented. Part B maps each one to its target and gives the RPC signatures
- Phase 1 database code: [`../supabase/`](../supabase/README.md) (migrations, seed, pgTAP tests, generated types).
- [RLS_AUTHORIZATION.md](architecture/RLS_AUTHORIZATION.md): **new**. The Supabase Auth model, RLS matrix, policies, Storage rules and RLS tests

### design/
- [UI_UX_AUDIT.md](design/UI_UX_AUDIT.md): the current UI, evaluated
- [DESIGN_SYSTEM.md](design/DESIGN_SYSTEM.md): a **proposed** design system
- [RESPONSIVE_DESIGN.md](design/RESPONSIVE_DESIGN.md)

### audit/
- [CODEBASE_AUDIT.md](audit/CODEBASE_AUDIT.md): structure, file inventory, unused and duplicate code
- [TECHNICAL_AUDIT.md](audit/TECHNICAL_AUDIT.md): frontend and backend engineering audit
- [SECURITY_AUDIT.md](audit/SECURITY_AUDIT.md)
- [PERFORMANCE_AUDIT.md](audit/PERFORMANCE_AUDIT.md)
- [BUGS_AND_ISSUES.md](audit/BUGS_AND_ISSUES.md): **master problem register**. Each issue is also reassessed against the target architecture
- [TECHNICAL_DEBT.md](audit/TECHNICAL_DEBT.md)

### planning/
- [DECISIONS.md](planning/DECISIONS.md): **new**. The log of approved, recommended and pending decisions
- [TECHNOLOGY_RECOMMENDATIONS.md](planning/TECHNOLOGY_RECOMMENDATIONS.md): Part B gives a verdict on each item in the proposed stack
- [MONGODB_TO_SUPABASE_MIGRATION.md](planning/MONGODB_TO_SUPABASE_MIGRATION.md): **not required**, because there is no production data (PD-06). Kept for reference only
- [REDESIGN_ROADMAP.md](planning/REDESIGN_ROADMAP.md): Part B is the **current** roadmap for the rebuild
- [IMPLEMENTATION_PLAN.md](planning/IMPLEMENTATION_PLAN.md): Part B is the **current** backlog

### changelog/
- [CHANGELOG.md](changelog/CHANGELOG.md)

## Pre-existing documentation

| File | Content |
|---|---|
| `Client/veny-frontend/README.md` | Unmodified Vite + React template boilerplate. It has no project-specific content. |
| `CLAUDE.md`, `AGENTS.md`, root `README.md`, `.env.example` | **Do not exist.** |

These docs don't modify any existing file.
