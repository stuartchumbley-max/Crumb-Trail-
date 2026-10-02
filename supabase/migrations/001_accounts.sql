-- Foundation only. Apply in your Supabase project's SQL editor.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null check (char_length(display_name) between 1 and 50),
  avatar_url text,
  home_city text,
  is_admin boolean not null default false,
  banned boolean not null default false,
  terms_accepted_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z][a-z0-9_]{2,19}$'),
  constraint username_reserved check (username not in ('admin','support','apple','google','crumbtrail','moderator'))
);
alter table public.profiles enable row level security;
-- No client can grant itself admin privileges, unban itself, or change acceptance.
revoke all on public.profiles from anon, authenticated;
grant select (id, username, display_name, avatar_url, home_city, created_at) on public.profiles to authenticated;
grant insert (id, username, display_name, avatar_url, home_city, terms_accepted_at) on public.profiles to authenticated;
grant update (username, display_name, avatar_url, home_city) on public.profiles to authenticated;
create policy profile_read on public.profiles for select to authenticated using (true);
create policy profile_create on public.profiles for insert to authenticated with check (id = auth.uid() and terms_accepted_at <= now() and terms_accepted_at > now() - interval '10 minutes');
create policy profile_edit on public.profiles for update to authenticated using (id = auth.uid() and not banned) with check (id = auth.uid());

-- Server-owned membership mirror. Populate from verified subscription webhooks
-- in a later phase; never trust a client-written trial or purchase flag.
create table public.memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  entitlement_id text not null default 'crumb_trail',
  expires_at timestamptz not null,
  store text not null check (store in ('app_store')),
  updated_at timestamptz not null default now()
);
alter table public.memberships enable row level security;
revoke all on public.memberships from anon, authenticated;
grant select on public.memberships to authenticated;
create policy membership_read on public.memberships for select to authenticated using (user_id = auth.uid());
