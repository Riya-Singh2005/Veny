-- Veny: core schema (extensions, enums, tables, constraints, indexes).
-- Source of truth: docs/architecture/DATABASE_ARCHITECTURE.md, Part B.
-- RLS is enabled on every table here, at creation time, so that no table is ever
-- exposed through the Data API without row level security. Policies are added in a
-- later migration; until then the default is deny.

create extension if not exists postgis with schema extensions;

-- Internal helpers (trigger functions, policy helpers) live in a schema that is NOT
-- exposed through the Data API.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------------
create type public.user_role         as enum ('customer', 'vendor');
create type public.vendor_status     as enum ('unverified', 'pending', 'verified', 'suspended');
create type public.booking_status    as enum ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled');
create type public.location_source   as enum ('gps', 'geocoded', 'manual_unverified');
create type public.notification_type as enum ('booking_new', 'booking_confirmed', 'booking_cancelled',
                                              'booking_in_progress', 'booking_completed', 'review_new');

-- ---------------------------------------------------------------------------
-- profiles: one row per auth.users row
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         public.user_role not null default 'customer',
  full_name    text not null check (char_length(full_name) between 2 and 80),
  phone_e164   text check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  avatar_path  text check (char_length(avatar_path) <= 300),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- ---------------------------------------------------------------------------
-- vendors: vendor-only attributes
-- ---------------------------------------------------------------------------
create table public.vendors (
  profile_id       uuid primary key references public.profiles (id) on delete cascade,
  business_name    text not null check (char_length(business_name) between 2 and 100),
  slug             text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 80),
  whatsapp_e164    text check (whatsapp_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  bio              text check (char_length(bio) <= 1000),
  logo_path        text check (char_length(logo_path) <= 300),
  base_location    extensions.geography(Point, 4326),
  service_radius_m integer not null default 10000 check (service_radius_m between 500 and 100000),
  status           public.vendor_status not null default 'unverified',
  verified_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index vendors_base_location_gix on public.vendors using gist (base_location);
alter table public.vendors enable row level security;

-- ---------------------------------------------------------------------------
-- categories: reference data (replaces the hardcoded enum)
-- ---------------------------------------------------------------------------
create table public.categories (
  id         smallint primary key generated always as identity,
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name       text not null unique check (char_length(name) between 2 and 60),
  icon       text check (char_length(icon) <= 60),
  sort_order smallint not null default 0,
  is_active  boolean not null default true
);
alter table public.categories enable row level security;

-- Production reference data: the six categories of the current app.
insert into public.categories (slug, name, icon, sort_order) values
  ('cleaning',    'Cleaning',    'sparkles',   1),
  ('repair',      'Repair',      'wrench',     2),
  ('salon',       'Salon',       'scissors',   3),
  ('electrician', 'Electrician', 'zap',        4),
  ('plumber',     'Plumber',     'droplets',   5),
  ('cooking',     'Cooking',     'chef-hat',   6);

-- ---------------------------------------------------------------------------
-- addresses (fixes BUG-02, BUG-03)
-- ---------------------------------------------------------------------------
create table public.addresses (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  label           text check (char_length(label) <= 40),
  line1           text not null check (char_length(line1) between 1 and 200),
  line2           text check (char_length(line2) <= 200),
  area            text not null check (char_length(area) between 1 and 100),
  city            text not null check (char_length(city) between 1 and 100),
  state           text not null check (char_length(state) between 1 and 100),
  postal_code     text check (postal_code ~ '^[0-9]{6}$'),
  country_code    char(2) not null default 'IN' check (country_code ~ '^[A-Z]{2}$'),
  location        extensions.geography(Point, 4326),
  location_source public.location_source not null,
  is_default      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index addresses_profile_id_idx on public.addresses (profile_id);
create unique index addresses_one_default_per_profile on public.addresses (profile_id) where is_default;
create index addresses_location_gix on public.addresses using gist (location);
alter table public.addresses enable row level security;

-- ---------------------------------------------------------------------------
-- services
-- ---------------------------------------------------------------------------
create table public.services (
  id               uuid primary key default gen_random_uuid(),
  vendor_id        uuid not null references public.vendors (profile_id) on delete restrict,
  category_id      smallint not null references public.categories (id) on delete restrict,
  slug             text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 120),
  title            text not null check (char_length(title) between 3 and 100),
  description      text not null check (char_length(description) between 10 and 2000),
  price_paise      integer not null check (price_paise >= 0),
  currency         char(3) not null default 'INR' check (currency ~ '^[A-Z]{3}$'),
  duration_minutes integer check (duration_minutes between 15 and 1440),
  location         extensions.geography(Point, 4326) not null,
  is_active        boolean not null default true,
  deleted_at       timestamptz,
  hidden_at        timestamptz,  -- set only by an admin (PD-13: hide listings); vendors cannot clear it
  avg_rating       numeric(2,1) not null default 0 check (avg_rating between 0 and 5),
  review_count     integer not null default 0 check (review_count >= 0),
  search_tsv       tsvector generated always as (
                     setweight(to_tsvector('simple'::regconfig, coalesce(title, '')), 'A') ||
                     setweight(to_tsvector('simple'::regconfig, coalesce(description, '')), 'B')
                   ) stored,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint services_deleted_inactive_chk check (deleted_at is null or not is_active)
);
create index services_location_gix   on public.services using gist (location);
create index services_search_tsv_gin on public.services using gin (search_tsv);
create index services_category_price_idx on public.services (category_id, price_paise)
  where is_active and deleted_at is null and hidden_at is null;
create index services_vendor_created_idx on public.services (vendor_id, created_at desc);
create index services_public_created_idx on public.services (created_at desc)
  where is_active and deleted_at is null and hidden_at is null;
alter table public.services enable row level security;

-- ---------------------------------------------------------------------------
-- service_images (fixes BUG-06)
-- ---------------------------------------------------------------------------
create table public.service_images (
  id           uuid primary key default gen_random_uuid(),
  service_id   uuid not null references public.services (id) on delete cascade,
  storage_path text not null check (char_length(storage_path) <= 300),
  alt_text     text check (char_length(alt_text) <= 200),
  position     smallint not null check (position between 0 and 3),
  created_at   timestamptz not null default now(),
  constraint service_images_position_uniq unique (service_id, position) deferrable initially immediate
);
alter table public.service_images enable row level security;

-- ---------------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------------
create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique check (reference ~ '^VNY-[0-9A-Z]{6}$'),
  service_id       uuid not null references public.services (id) on delete restrict,
  customer_id      uuid not null references public.profiles (id) on delete restrict,
  vendor_id        uuid not null references public.vendors (profile_id) on delete restrict,
  status           public.booking_status not null default 'pending',
  scheduled_at     timestamptz not null,
  customer_notes   text check (char_length(customer_notes) <= 1000),
  address_snapshot jsonb not null check (jsonb_typeof(address_snapshot) = 'object'),
  address_location extensions.geography(Point, 4326),
  price_paise      integer not null check (price_paise >= 0),
  currency         char(3) not null check (currency ~ '^[A-Z]{3}$'),
  cancelled_by     uuid references public.profiles (id) on delete set null,
  cancel_reason    text check (char_length(cancel_reason) <= 500),
  confirmed_at     timestamptz,
  started_at       timestamptz,
  completed_at     timestamptz,
  cancelled_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint bookings_not_self_chk       check (customer_id <> vendor_id),
  constraint bookings_cancelled_chk      check ((status = 'cancelled') = (cancelled_at is not null)),
  constraint bookings_completed_chk      check ((status = 'completed') = (completed_at is not null)),
  constraint bookings_scheduled_future_chk check (scheduled_at > created_at)
);
create index bookings_customer_created_idx  on public.bookings (customer_id, created_at desc);
create index bookings_vendor_status_sched_idx on public.bookings (vendor_id, status, scheduled_at);
create index bookings_vendor_created_idx    on public.bookings (vendor_id, created_at desc);
create index bookings_service_idx           on public.bookings (service_id);
create index bookings_cancelled_by_idx      on public.bookings (cancelled_by);
alter table public.bookings enable row level security;

-- ---------------------------------------------------------------------------
-- booking_status_history (insert-only audit trail)
-- ---------------------------------------------------------------------------
create table public.booking_status_history (
  id          bigint primary key generated always as identity,
  booking_id  uuid not null references public.bookings (id) on delete cascade,
  from_status public.booking_status,
  to_status   public.booking_status not null,
  changed_by  uuid references public.profiles (id) on delete set null,
  reason      text check (char_length(reason) <= 500),
  created_at  timestamptz not null default now()
);
create index booking_status_history_booking_idx on public.booking_status_history (booking_id, created_at);
create index booking_status_history_changed_by_idx on public.booking_status_history (changed_by);
alter table public.booking_status_history enable row level security;

-- ---------------------------------------------------------------------------
-- reviews: one per booking (ADR-017)
-- ---------------------------------------------------------------------------
create table public.reviews (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null unique references public.bookings (id) on delete restrict,
  service_id   uuid not null references public.services (id) on delete restrict,
  customer_id  uuid not null references public.profiles (id) on delete restrict,
  author_name  text not null check (char_length(author_name) between 1 and 40),  -- public display snapshot, e.g. "Asha K."
  rating       smallint not null check (rating between 1 and 5),
  comment      text check (char_length(comment) <= 500),
  vendor_reply text check (char_length(vendor_reply) <= 500),
  is_hidden    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index reviews_service_visible_idx on public.reviews (service_id, created_at desc) where not is_hidden;
create index reviews_service_idx  on public.reviews (service_id);
create index reviews_customer_idx on public.reviews (customer_id);
alter table public.reviews enable row level security;

-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       public.notification_type not null,
  title      text not null check (char_length(title) <= 120),
  body       text not null check (char_length(body) <= 1000),
  link       text check (link ~ '^/[^/]' and char_length(link) <= 300),
  booking_id uuid references public.bookings (id) on delete cascade,
  read_at    timestamptz,
  emailed_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index notifications_user_unread_idx  on public.notifications (user_id) where read_at is null;
create index notifications_booking_idx      on public.notifications (booking_id);
alter table public.notifications enable row level security;

-- ---------------------------------------------------------------------------
-- admin_users (PD-01) and admin_audit_log (PD-13)
-- ---------------------------------------------------------------------------
create table public.admin_users (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now()
);
create index admin_users_granted_by_idx on public.admin_users (granted_by);
alter table public.admin_users enable row level security;

create table public.admin_audit_log (
  id           bigint primary key generated always as identity,
  actor_id     uuid references public.profiles (id) on delete set null,
  action       text not null check (char_length(action) <= 60),
  target_table text not null check (char_length(target_table) <= 60),
  target_id    text not null check (char_length(target_id) <= 100),
  before       jsonb,
  after        jsonb,
  note         text check (char_length(note) <= 1000),
  created_at   timestamptz not null default now()
);
create index admin_audit_log_actor_idx  on public.admin_audit_log (actor_id, created_at desc);
create index admin_audit_log_target_idx on public.admin_audit_log (target_table, target_id);
alter table public.admin_audit_log enable row level security;
