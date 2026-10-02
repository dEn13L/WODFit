-- Internal notifications for newly published workouts.
-- This migration is prepared for manual execution in Supabase SQL Editor.

alter table public.workouts
  add column if not exists published_at timestamptz;

update public.workouts
set published_at = coalesce(updated_at, created_at, now())
where status = 'published'
  and published_at is null;

create or replace function public.set_workout_published_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists set_workout_published_at on public.workouts;
create trigger set_workout_published_at
before insert or update of status on public.workouts
for each row execute function public.set_workout_published_at();

create table if not exists public.workout_views (
  workout_id uuid not null references public.workouts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (workout_id, user_id)
);

create index if not exists idx_workout_views_user
  on public.workout_views(user_id, viewed_at desc);

alter table public.workout_views enable row level security;

drop policy if exists "Clients can view own workout views" on public.workout_views;
create policy "Clients can view own workout views"
  on public.workout_views for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Clients can create own workout views" on public.workout_views;
create policy "Clients can create own workout views"
  on public.workout_views for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.can_user_view_workout(workout_id, auth.uid())
  );

drop policy if exists "Clients can update own workout views" on public.workout_views;
create policy "Clients can update own workout views"
  on public.workout_views for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and public.can_user_view_workout(workout_id, auth.uid())
  );

revoke all on table public.workout_views from anon;
grant select, insert, update on table public.workout_views to authenticated;
