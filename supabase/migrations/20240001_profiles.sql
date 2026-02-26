-- ============================================================
-- XomFit: User Profiles table + Storage bucket
-- ============================================================

-- 1. Profiles table
create table if not exists public.profiles (
    id              uuid references auth.users on delete cascade primary key,
    username        text unique not null,
    display_name    text not null default '',
    bio             text not null default '',
    avatar_url      text,
    is_private      boolean not null default false,

    -- Lifetime stats (updated by triggers / Edge Functions when workouts save)
    total_workouts  integer not null default 0,
    total_volume    float8  not null default 0,
    total_prs       integer not null default 0,
    current_streak  integer not null default 0,
    longest_streak  integer not null default 0,
    favorite_exercise text,

    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- 2. Auto-update updated_at
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.handle_updated_at();

-- 3. Row Level Security
alter table public.profiles enable row level security;

-- Anyone can read public profiles; private profiles visible only to owner
create policy "Public profiles are readable by all"
  on public.profiles for select
  using (is_private = false or auth.uid() = id);

-- Users can only insert/update their own profile
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 4. Storage bucket for avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Allow any authenticated user to upload to their own folder
create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow any authenticated user to update their own avatar
create policy "Users can update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Public read for avatars (bucket is already public; belt-and-suspenders)
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');
