-- Optional starting schema only. No Supabase client, authentication, RLS policy,
-- migrations, or sync service is configured by this Flutter app.
create table if not exists public.farmer_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.farms (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.farmer_profiles(id) on delete cascade,
  name text not null,
  location text,
  created_at timestamptz not null default now()
);

create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  name text not null,
  area_ha numeric check (area_ha > 0)
);

create table if not exists public.soil_analyses (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  nitrogen numeric not null check (nitrogen >= 0),
  phosphorus numeric not null check (phosphorus >= 0),
  potassium numeric not null check (potassium >= 0),
  unit text not null,
  test_method text,
  tested_at timestamptz not null default now()
);

create table if not exists public.crop_selections (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  crop text not null,
  region text,
  created_at timestamptz not null default now()
);

create table if not exists public.fertilizer_recommendations (
  id uuid primary key default gen_random_uuid(),
  analysis_id uuid not null references public.soil_analyses(id) on delete cascade,
  crop text,
  result jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.assistant_messages (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.farmer_profiles(id) on delete cascade,
  conversation_id uuid not null,
  role text not null check (role in ('farmer','assistant')),
  content text not null,
  sources jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Before deployment: enable RLS on every table and add owner-scoped policies.
-- Never ship a service-role key in the Flutter application.
