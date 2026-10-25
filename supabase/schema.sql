-- FitStreak: published routines and who follows them.
-- Paste it whole in Supabase → SQL Editor → Run. It can be run again.
--
-- Model:
--   routines: one row per published routine. id = short code (FS-XXXXXX
--             without the prefix). Only the owner creates, changes or deletes it.
--   follows:  who follows which routine (to count followers).
-- Nobody can list every routine: they are read by code with get_routines().
-- Only those the author marks as public show in search_routines() (at the end).

create table if not exists public.routines (
  id         text primary key check (id ~ '^[2-9A-HJ-NP-Z]{6}$'),
  owner      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  author     text not null check (char_length(author) between 1 and 40),
  title      text not null check (char_length(title) between 1 and 80),
  -- {"routine": {...}, "custom": [...]}: the same as the FITSTREAK1 code carries.
  payload    jsonb not null check (octet_length(payload::text) < 200000),
  version    integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists routines_owner_idx on public.routines (owner);

create table if not exists public.follows (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  routine_id text not null references public.routines (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, routine_id)
);

create index if not exists follows_routine_idx on public.follows (routine_id);

-- Every content change bumps the version, so followers know there is something new.
-- The id and the owner cannot change.
create or replace function public.routines_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.id := old.id;
  new.owner := old.owner;
  new.created_at := old.created_at;
  if new.payload is distinct from old.payload
     or new.title is distinct from old.title
     or new.author is distinct from old.author then
    new.version := old.version + 1;
    new.updated_at := now();
  else
    new.version := old.version;
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

drop trigger if exists routines_before_update on public.routines;
create trigger routines_before_update
  before update on public.routines
  for each row execute function public.routines_before_update();

-- Per-user limit so an anonymous account can't fill the database.
create or replace function public.routines_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.owner := auth.uid();
  new.version := 1;
  if (select count(*) from public.routines r where r.owner = new.owner) >= 20 then
    raise exception 'Demasiadas rutinas publicadas' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists routines_before_insert on public.routines;
create trigger routines_before_insert
  before insert on public.routines
  for each row execute function public.routines_before_insert();

alter table public.routines enable row level security;
alter table public.follows enable row level security;

-- Tables: only the owner sees and touches their rows. Others read by code (below).
drop policy if exists "routines: el dueño las ve" on public.routines;
create policy "routines: el dueño las ve" on public.routines
  for select to authenticated using (owner = (select auth.uid()));

drop policy if exists "routines: el dueño publica" on public.routines;
create policy "routines: el dueño publica" on public.routines
  for insert to authenticated with check (owner = (select auth.uid()));

drop policy if exists "routines: el dueño edita" on public.routines;
create policy "routines: el dueño edita" on public.routines
  for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()));

drop policy if exists "routines: el dueño borra" on public.routines;
create policy "routines: el dueño borra" on public.routines
  for delete to authenticated using (owner = (select auth.uid()));

drop policy if exists "follows: los míos" on public.follows;
create policy "follows: los míos" on public.follows
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Reads routines by code (whoever has the code can read it), with the follower
-- count. At most 50 codes per call.
create or replace function public.get_routines(ids text[])
returns table (
  id text, author text, title text, payload jsonb, version integer,
  updated_at timestamptz, followers bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.author, r.title, r.payload, r.version, r.updated_at,
         (select count(*) from public.follows f where f.routine_id = r.id)
  from public.routines r
  where r.id = any (ids[1:50]);
$$;

-- Grants (the project doesn't expose new tables automatically).
revoke all on public.routines, public.follows from anon, authenticated;
grant select, insert, update, delete on public.routines to authenticated;
grant select, insert, delete on public.follows to authenticated;
revoke all on function public.get_routines(text[]) from public;
grant execute on function public.get_routines(text[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Routine search (optional for the author).
-- By default a routine stays private: only whoever has the code finds it. If
-- the author turns on "Que aparezca en el buscador", anyone can find it by the
-- author's name or the routine's.
alter table public.routines add column if not exists is_public boolean not null default false;

-- Changing is_public doesn't bump the version (the trigger only checks content).
-- Returns the same as get_routines without the content (payload): to follow
-- one it is then read by code. Without text, the most followed.
create or replace function public.search_routines(q text, lim integer default 20)
returns table (
  id text, author text, title text, version integer,
  updated_at timestamptz, followers bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  -- strpos instead of ilike, so % and _ in the text are searched literally.
  select r.id, r.author, r.title, r.version, r.updated_at, count(f.user_id)
  from public.routines r
  left join public.follows f on f.routine_id = r.id
  where r.is_public
    and (coalesce(btrim(q), '') = ''
         or strpos(lower(r.author), lower(btrim(q))) > 0
         or strpos(lower(r.title), lower(btrim(q))) > 0)
  group by r.id
  order by count(f.user_id) desc, r.updated_at desc
  limit least(greatest(coalesce(lim, 20), 1), 50);
$$;

revoke all on function public.search_routines(text, integer) from public;
grant execute on function public.search_routines(text, integer) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Account deletion (required by Google Play): "Borrar todos los datos" in the
-- app deletes the user; routines and follows go with it (on delete cascade).
create or replace function public.delete_my_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
