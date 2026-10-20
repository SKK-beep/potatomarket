-- Potato Farmers Market: PostgreSQL / Supabase starter schema
-- Review with a developer before production. Store prices in KSh as numeric values.
-- Do not expose private contact fields or admin-only data through public policies.

create extension if not exists pgcrypto;

create type public.user_role as enum ('seller','buyer','admin');
create type public.listing_kind as enum ('ware','seed');
create type public.quantity_unit as enum ('bags','kg','tonnes','acres');
create type public.price_basis as enum ('per_bag','per_kg','per_tonne','total_lot','negotiable');
create type public.review_status as enum ('pending','approved','rejected','suspended');
create type public.payment_status as enum ('pending','paid','failed','refunded');
create type public.prediction_horizon as enum ('14_days','30_days','90_days');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'buyer',
  display_name text not null,
  phone text,
  phone_verified_at timestamptz,
  county text,
  town_or_market text,
  contact_visibility text not null default 'paid_members'
    check (contact_visibility in ('paid_members','matched_users','private')),
  created_at timestamptz not null default now()
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id),
  kind public.listing_kind not null,
  variety text not null,
  variety_other text,
  generation_or_class text, -- required by application for seed listings
  quantity_unit public.quantity_unit not null,
  quantity numeric(14,3) not null check (quantity > 0),
  bag_weight_kg numeric(8,3),
  local_bag_name text,
  price_ksh numeric(14,2) not null check (price_ksh >= 0),
  price_basis public.price_basis not null,
  location_county text not null,
  location_town_market text not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  seller_phone_snapshot text, -- keep private; expose only through protected server endpoint
  description text,
  harvest_date date,
  available_until date,
  status public.review_status not null default 'pending',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (quantity_unit = 'bags' and bag_weight_kg is not null and bag_weight_kg > 0 and local_bag_name is not null)
    or quantity_unit <> 'bags'
  ),
  check (kind <> 'seed' or (generation_or_class is not null and length(trim(generation_or_class)) > 0))
);

create table public.listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  storage_path text not null,
  media_kind text not null default 'potato_photo'
    check (media_kind in ('potato_photo','packaging_photo','seed_label','certificate_document','other')),
  uploaded_at timestamptz not null default now(),
  review_status public.review_status not null default 'pending',
  reviewer_id uuid references public.profiles(id),
  reviewer_note text
);

create table public.buyer_enquiries (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id),
  kind public.listing_kind not null,
  variety text not null,
  variety_other text,
  required_generation_or_class text,
  quantity_unit public.quantity_unit not null,
  quantity numeric(14,3) not null check (quantity > 0),
  bag_weight_kg numeric(8,3),
  local_bag_name text,
  max_price_ksh numeric(14,2),
  price_basis public.price_basis not null default 'negotiable',
  delivery_county text not null,
  delivery_town_market text not null,
  needed_by date,
  delivery_required boolean not null default false,
  notes text,
  status public.review_status not null default 'pending',
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (quantity_unit = 'bags' and bag_weight_kg is not null and bag_weight_kg > 0)
    or quantity_unit <> 'bags'
  ),
  check (kind <> 'seed' or required_generation_or_class is not null)
);

create table public.enquiry_responses (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.buyer_enquiries(id) on delete cascade,
  seller_id uuid not null references public.profiles(id),
  listing_id uuid references public.listings(id),
  message text,
  offered_quantity numeric(14,3),
  offered_price_ksh numeric(14,2),
  created_at timestamptz not null default now(),
  unique (enquiry_id, seller_id)
);

create table public.market_price_observations (
  id uuid primary key default gen_random_uuid(),
  variety text not null,
  market_name text not null,
  county text not null,
  product_kind public.listing_kind not null default 'ware',
  generation_or_class text,
  price_ksh_per_kg numeric(14,2) not null check (price_ksh_per_kg >= 0),
  observed_on date not null,
  source_name text,
  source_url text,
  notes text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.price_predictions (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.profiles(id),
  variety text not null,
  market_name text not null,
  county text not null,
  horizon public.prediction_horizon not null,
  current_price_ksh_per_kg numeric(14,2) not null check (current_price_ksh_per_kg > 0),
  predicted_price_ksh_per_kg numeric(14,2) not null check (predicted_price_ksh_per_kg >= 0),
  submitted_at timestamptz not null default now(),
  target_date date not null,
  is_current boolean not null default true
);
create unique index one_current_prediction_per_farmer
  on public.price_predictions (farmer_id, variety, market_name, horizon)
  where is_current = true;

create table public.forecast_outcomes (
  id uuid primary key default gen_random_uuid(),
  prediction_id uuid not null references public.price_predictions(id) on delete cascade,
  actual_price_ksh_per_kg numeric(14,2) not null check (actual_price_ksh_per_kg >= 0),
  observed_on date not null,
  source_name text,
  recorded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (prediction_id, observed_on)
);

create table public.platform_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);
-- Suggested setting keys: seller_listing_fee_ksh, buyer_subscription_plans,
-- listing_duration_days, buyer_contact_access_days, allowed_bag_sizes_kg,
-- supported_varieties, seed_classes, enquiry_expiry_days.

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  purpose text not null check (purpose in ('seller_listing','buyer_subscription','renewal','other')),
  amount_ksh numeric(14,2) not null check (amount_ksh >= 0),
  status public.payment_status not null default 'pending',
  provider text not null default 'mpesa',
  provider_reference text unique,
  related_listing_id uuid references public.listings(id),
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table public.buyer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id),
  payment_id uuid not null references public.payment_transactions(id),
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  active boolean not null default true
);

-- Important production work not included in this schema:
-- 1. Configure Supabase Row Level Security on every table and Storage bucket.
-- 2. Public users may only read approved, non-expired listings and approved enquiries.
-- 3. Contact phone fields must be hidden from public queries and released via server-side
--    authorization only after the relevant payment/access rule has been checked.
-- 4. Only admins may change platform_settings, approve seed evidence, or publish prices.
-- 5. Verify M-Pesa callbacks server-side; never trust a browser success message.
-- 6. Add audit logs, rate limits, account deletion/export flows, and backup policies.
