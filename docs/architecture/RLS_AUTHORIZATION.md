# Supabase Authorization & Row Level Security — PROPOSED

> **Status (2026-11-17): implemented locally** in `supabase/migrations/20261117000300_rls_grants.sql` and `20261117000400_storage.sql`, and covered by `supabase/tests/database/`. Not yet applied to staging. Differences from the sketches below are listed in DATABASE_ARCHITECTURE.md Part B §0. The main ones: helpers live in the `private` schema; public vendor fields use column grants rather than a view; review author names are a snapshot column; admin actions go through `admin_*` RPCs.
>
> Original status: proposal. The schema is in [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md), Part B. Decision IDs (ADR-xxx, PD-xx) refer to [../planning/DECISIONS.md](../planning/DECISIONS.md).
> The SQL in this document is illustrative. Final policies must be written as migrations and **tested** (§9) before use.

## 1. Principles
1. **The database is the security boundary.** Every table in `public` has RLS enabled. Frontend role checks are UX only.
2. **Default deny.** A table with RLS enabled and no matching policy returns nothing. Policies are added only where access is needed.
3. **Writes with business rules go through RPC.** `bookings`, `reviews`, `booking_status_history` and the counters on `services` are written only by `SECURITY DEFINER` functions. These functions validate `auth.uid()` and the full invariant.
4. **Least-privilege column grants.** RLS controls rows, not columns. Column privileges (`revoke update … ; grant update (col, …)`) protect fields such as `profiles.role`, `vendors.status` and `services.avg_rating`.
5. **Secrets stay on the server.**
   - The browser gets only the **publishable/anon key**.
   - The service-role or secret key is used only in Edge Functions and in Next.js server code that never reaches the client bundle. It lives only in Vercel and Supabase server environment variables, never with a `NEXT_PUBLIC_` prefix.
   - Code that uses the service role must enforce authorization itself, because it bypasses RLS. Keep it to a minimum: admin operations, account deletion, the email worker.
6. **Users can't grant themselves privilege.**
   - The role can only be `customer` or `vendor`. It is set once by the signup trigger.
   - Vendor `status` is admin-only.
   - Admin rights are a separate table with no client write path.
7. **Policies use the `(select auth.uid())` form** so the value is evaluated once per query (Supabase performance guidance). Every column used in a policy predicate is indexed.

## 2. Authentication model (ADR-005; PD-03 decided: email + password)
| Concern | Design |
|---|---|
| Sign-up | `supabase.auth.signUp({ email, password, options: { data: { full_name, role } } })`, called from a **Server Action**. Email confirmation is **required** (Auth setting). The confirmation email is sent by Supabase Auth through **Resend SMTP**. The client never sees a code or token, which closes SEC-01 and SEC-02 |
| Sign-in | **Email + password** (PD-03), with email confirmation required before first sign-in. Passwordless OTP or magic link is an optional later addition. Any codes go only to the inbox, through Supabase Auth |
| Session | `@supabase/ssr` sets **httpOnly, Secure, SameSite=Lax cookies**, refreshed by Next.js middleware. This fixes SEC-06 |
| Rate limits | Supabase Auth's built-in limits on sign-up, OTP and verify, plus CAPTCHA (Turnstile or hCaptcha) on sign-up and sign-in, which Supabase Auth supports. Fixes SEC-08 |
| Password policy | Minimum 8 characters, with leaked-password protection if the plan supports it (Requires Verification) |
| Enumeration | Supabase Auth returns generic responses for sign-up and reset when configured to (Requires Verification). The UI always shows "If an account exists, we've emailed you". Fixes SEC-12 |
| Password reset | `resetPasswordForEmail` sends the user to a `/auth/reset` route. Adds a missing feature (F30) |
| Server-side identity | Server code calls `supabase.auth.getUser()` (verified with the Auth server), **not** `getSession()`, before trusting the identity |
| Role in the UI | Read from `profiles` on the server in the dashboard layout. It is **not** taken from the JWT or localStorage |

**Critical rule:** none of the current OTP code (`authController.js` OTP generation, `VerifyOTP.jsx` `frontendOtp`, EmailJS) is ported. A database migration alone does **not** fix SEC-01. Fixing it depends on letting Supabase Auth own verification.

## 3. Role & privilege model
| Actor | How identified | Can become via |
|---|---|---|
| `anon` | No session | — |
| Customer | `profiles.role = 'customer'` | Sign-up (default) |
| Vendor | `profiles.role = 'vendor'` (and a `vendors` row) | Sign-up with role vendor (PD-04). `status` starts at `unverified` |
| Verified vendor | `vendors.status = 'verified'` | An admin action only (PD-02) |
| Admin | A row in `admin_users` (PD-01: approved) | A SQL migration or service-role script only |
| Service role | Secret key | Server and Edge only |

Helper functions, each `stable` and `SECURITY DEFINER` with `search_path = ''`:
- `public.is_admin() returns boolean`
- `public.is_vendor() returns boolean`, which checks for a row in `vendors` where `profile_id = auth.uid()`
- `public.is_booking_participant(b uuid) returns boolean`

## 4. Per-table policies

Legend: ✅ policy allows · ❌ no policy (denied) · RPC = only through the named function · 🔒 column-restricted

### 4.1 Authorization matrix

| Table | Operation | anon | Customer | Vendor | Admin |
|---|---|---|---|---|---|
| `profiles` | SELECT | ❌ (public vendor info via a view) | ✅ own row | ✅ own row | ✅ all |
| | INSERT | ❌ | ❌ (trigger) | ❌ (trigger) | ❌ |
| | UPDATE | ❌ | ✅ own, 🔒 `full_name, phone_e164, avatar_path` | same | ✅ |
| | DELETE | ❌ | ❌ (account-deletion function) | ❌ | service role |
| `vendors` | SELECT | ✅ public columns only (column grant), non-suspended | same | same + own private fields via `get_my_vendor()` | ✅ public columns |
| | UPDATE | ❌ | ❌ | ✅ own, 🔒 `business_name, whatsapp_e164, bio, base_location, service_radius_m` | ✅ including `status` |
| `vendor_verifications` (PD-02) | SELECT | ❌ | ❌ | ✅ own | ✅ |
| | INSERT | ❌ | ❌ | ✅ own, `status = 'submitted'` only | ✅ |
| | UPDATE | ❌ | ❌ | ❌ | ✅ |
| `categories` | SELECT | ✅ active | ✅ | ✅ | ✅ |
| | write | ❌ | ❌ | ❌ | ✅ |
| `addresses` | ALL | ❌ | ✅ own (`profile_id = auth.uid()`) | ✅ own | ✅ read |
| `services` | SELECT | ✅ `is_active and deleted_at is null` and vendor not suspended | same | same **plus own (including paused or deleted)**, which fixes BE-07 | ✅ |
| | INSERT | ❌ | ❌ | ✅ `vendor_id = auth.uid()` and `is_vendor()` | ✅ |
| | UPDATE | ❌ | ❌ | ✅ own, 🔒 editable columns (DATABASE_ARCHITECTURE §4.6) | ✅ |
| | DELETE | ❌ | ❌ | RPC `soft_delete_service` | ✅ |
| `service_images` | SELECT | ✅ if the parent service is visible | same | same + own | ✅ |
| | INSERT/UPDATE/DELETE | ❌ | ❌ | ✅ if `service.vendor_id = auth.uid()` | ✅ |
| `bookings` | SELECT | ❌ | ✅ `customer_id = auth.uid()` | ✅ `vendor_id = auth.uid()` (a vendor who booked as a customer also sees those rows) | ✅ |
| | INSERT | ❌ | RPC `create_booking` | RPC `create_booking` (other vendors' services, if allowed by product) | — |
| | UPDATE | ❌ | RPC `transition_booking` (cancel only) | RPC `transition_booking` | RPC |
| | DELETE | ❌ | ❌ | ❌ | service role |
| `booking_status_history` | SELECT | ❌ | ✅ if a participant | ✅ if a participant | ✅ |
| | write | ❌ | RPC | RPC | RPC |
| `reviews` | SELECT | ✅ `not is_hidden` | ✅ | ✅ | ✅ including hidden |
| | INSERT | ❌ | RPC `create_review` | RPC (only if they were the customer) | — |
| | UPDATE | ❌ | ✅ own, 🔒 `rating, comment`, within 7 days (proposal) | ✅ 🔒 `vendor_reply` on reviews of own services (future) | ✅ `is_hidden` |
| | DELETE | ❌ | ✅ own | ❌ | ✅ |
| `notifications` | SELECT | ❌ | ✅ own | ✅ own | own |
| | UPDATE | ❌ | ✅ own, 🔒 `read_at` (fixes SEC-09) | same | — |
| | DELETE | ❌ | ✅ own | ✅ own | — |
| | INSERT | ❌ | ❌ (triggers and RPC only) | ❌ | service role |
| `admin_users` | ALL | ❌ | ❌ | ❌ | ❌ (service role only) |

### 4.2 Policy sketches

```sql
-- Enable RLS everywhere
alter table public.profiles enable row level security;
-- … repeat for every public table

-- profiles: self read / limited self update
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from authenticated;
grant update (full_name, phone_e164, avatar_path) on public.profiles to authenticated;

-- services: public catalogue + owner management
create policy services_public_read on public.services
  for select to anon, authenticated
  using (is_active and deleted_at is null
         and exists (select 1 from public.vendors v
                     where v.profile_id = services.vendor_id and v.status <> 'suspended'));
create policy services_owner_read on public.services
  for select to authenticated using (vendor_id = (select auth.uid()));
create policy services_owner_insert on public.services
  for insert to authenticated
  with check (vendor_id = (select auth.uid()) and (select public.is_vendor()));
create policy services_owner_update on public.services
  for update to authenticated
  using (vendor_id = (select auth.uid())) with check (vendor_id = (select auth.uid()));
revoke update on public.services from authenticated;
grant update (category_id, title, description, price_paise, duration_minutes,
              location, is_active, slug) on public.services to authenticated;

-- bookings: participants read; no direct writes
create policy bookings_participant_read on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid()) or vendor_id = (select auth.uid()));
revoke insert, update, delete on public.bookings from authenticated, anon;
-- create_booking / transition_booking are SECURITY DEFINER and validate auth.uid()

-- notifications: owner only, read flag only
create policy notif_owner_read on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy notif_owner_update on public.notifications
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notif_owner_delete on public.notifications
  for delete to authenticated using (user_id = (select auth.uid()));
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;
```

### 4.3 Admin policy pattern (PD-01 approved; powers per PD-13 option b)

Admin powers in v1 are: verify and suspend vendors, hide reviews and listings, view all bookings, cancel bookings from any non-terminal state, and manage categories. Admins **cannot** change user roles, grant admin rights, impersonate users, or edit other users' profiles or listings, beyond hiding them.

Admin access is **added as separate permissive policies**. It is never folded into the user policies, so each grant is easy to audit. Every admin write also inserts a row into an `admin_audit_log` table (proposed: actor, action, target table, target id, before/after JSON, timestamp), written by a trigger or by the admin RPC.

```sql
-- example: admins can read every booking and moderate reviews
create policy bookings_admin_read on public.bookings
  for select to authenticated using ((select public.is_admin()));
create policy reviews_admin_moderate on public.reviews
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
-- vendors.status is changed only through an admin RPC, never through a column grant to authenticated:
-- admin_set_vendor_status(p_vendor_id uuid, p_status vendor_status, p_note text)  SECURITY DEFINER, checks is_admin()
-- (implemented; also admin_set_review_hidden and admin_set_service_hidden)
```

- The first admin is created per PD-14. Granting further admins happens only through a migration or a service-role script. **There is no UI path to grant admin in v1.**
- Admin accounts should use MFA (Supabase Auth TOTP). Requires Verification: plan support and enforcement options.

## 5. Counterparty data (PII) access
Today `my-bookings` returns the other party's email and phone at all times (`bookingController.js:76-79`).

Proposed:
- `profiles` isn't readable across users.
- Public vendor fields come from a **column-level SELECT grant** on `vendors`: business name, slug, bio, logo and verification status. No view is used, so there is no security-definer view for the Advisor to flag. *(This replaces the earlier `public_vendor_profiles` view design.)*
- Contact details come from `get_booking_contact(booking_id)` RPC, and only for participants of a booking in `confirmed` or `in_progress` status.
- Customer display names on reviews come from `reviews.author_name`, a first-name-plus-initial snapshot written by `create_review()`. *(This replaces the earlier `public_review_authors` projection.)*

## 6. Storage buckets & policies

| Bucket | Public? | Path convention | Read | Write |
|---|---|---|---|---|
| `service-images` | Public read | `{vendor_id}/{service_id}/{uuid}.{ext}` | anyone | `insert/update/delete` only when `(storage.foldername(name))[1] = auth.uid()::text`. MIME types image/jpeg, png and webp; size ≤ 5 MB (bucket config) |
| `avatars` | Public read | `{user_id}/{uuid}.{ext}` | anyone | owner prefix only, ≤ 2 MB |
| `verification-docs` (PD-02) | **Private** | `{vendor_id}/{uuid}.{ext}` | owner and admin through signed URLs | owner insert only |

- Uploads use **signed upload URLs** created in a Server Action after Zod validation, or direct client uploads constrained by the policies above.
- Image transformations use Supabase Storage image resizing where the plan supports it (Requires Verification). Otherwise a resize Edge Function runs on upload.

## 7. Realtime authorization
- Realtime `postgres_changes` respects RLS. Subscriptions are limited to `notifications` (filter `user_id=eq.<uid>`) and `bookings` (vendor inbox).
- Publish only those tables in the `supabase_realtime` publication.
- Requires Verification: the current Realtime Authorization model (Broadcast and Presence private channels) if those features are used later.

## 8. Edge Functions & Server code security
| Component | Key | Auth check |
|---|---|---|
| Next.js Server Actions / Route Handlers | anon key + user cookie (RLS applies) | `getUser()`. RLS enforces the rest |
| `send-notification-email` Edge Function | service role (to read the recipient's email) | Triggered by a database webhook or queue with a **shared secret header**, so it can't be called publicly. It escapes all interpolated values (SEC-07) and sets `emailed_at` for idempotency |
| `delete-account` Edge Function | service role | Verifies the caller's JWT, then anonymises and deletes |
| Admin actions | user JWT + `is_admin()` in RLS, or service role after an `is_admin()` check | — |

Every `SECURITY DEFINER` function:
- Sets `search_path = ''`.
- Revokes `execute` from `public` and `anon`.
- Never takes the acting user's ID as a parameter; it always uses `auth.uid()`.
- Raises typed errors (SQLSTATE + message) that the server maps to user messages (BUG-01).

## 9. Testing RLS (mandatory, ADR-014)
- Run the local Supabase CLI stack in CI.
- For each policy, write tests as **anon, customer A, customer B, vendor A, vendor B, admin**, asserting both allowed and denied cases. Use pgTAP (`supabase test db`) or Vitest with per-role JWTs.
- Required negative tests:
  - Customer B can't read customer A's bookings or addresses.
  - A vendor can't update another vendor's service or change `avg_rating`.
  - Nobody can update `profiles.role` or `vendors.status`, except admin or the service role.
  - Nobody can review a booking that isn't completed, or one that belongs to someone else.
  - Nobody can mark another user's notification as read.
  - `anon` can't see paused, deleted or suspended-vendor services.
  - Direct `insert into bookings` fails for `authenticated`.
- Run Supabase's **Security Advisor and Performance Advisor** lints (RLS disabled, mutable `search_path`, unindexed FKs) as a CI gate.

## 10. New risks introduced by this architecture
| Risk | Mitigation |
|---|---|
| A table created without RLS is exposed through the auto-generated REST API (PostgREST) | Migration template enables RLS; CI advisor check; consider removing tables from the exposed schema if they don't need to be reachable |
| SECURITY DEFINER function misuse (search_path hijack, missing auth check) | The rules in §8; code review checklist; tests |
| A service-role key leaks into the client bundle | Naming convention (no `NEXT_PUBLIC_`); `server-only` import guard; CI grep for the key pattern |
| Views bypassing RLS and leaking columns | Explicit column lists; `security_invoker` where appropriate; tests |
| Anon key abuse (scraping, spam sign-ups) | CAPTCHA, Auth rate limits, `search_services` limit clamps |
| Overly broad Realtime publication | Publish only `notifications` and `bookings` |
