-- Каталожная структура live на 2026-10-03 после 10/11; без пользовательских данных.
-- Только одноразовая локальная БД/CI. auth.users и auth.uid — тестовые заменители Supabase Auth.
create role anon; create role authenticated; create role service_role bypassrls;
create schema auth; create schema private;
grant usage on schema auth, public to anon, authenticated;
grant usage on schema private to authenticated;
create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$select (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;
create type public."program_kind" as enum ('personal','group');
create type public."result_status" as enum ('done','scaled','notDone');
create type public."user_role" as enum ('coach','client');
create type public."workout_part_type" as enum ('warmup','weightlifting','strength','crossfitComplex','cooldown','stretch','mobility');
create type public."workout_status" as enum ('draft','published');
create table public."part_results"("id" uuid not null default gen_random_uuid(),"workout_id" uuid not null,"part_id" uuid not null,"user_id" uuid not null,"status" result_status not null default 'done'::result_status,"score_text" text not null default ''::text,"note" text not null default ''::text,"time_ms" bigint,"rounds" integer,"reps" integer,"weight_kg" numeric(6,2),"created_at" timestamp with time zone not null default timezone('utc'::text, now()),"updated_at" timestamp with time zone not null default timezone('utc'::text, now()),"distance_m" numeric(8,2),"calories" integer,"score_type" text,"client_updated_at" timestamp with time zone not null default now(),"last_operation_id" uuid not null default gen_random_uuid(),"deleted_at" timestamp with time zone);
create table public."profiles"("id" uuid not null,"email" text not null,"full_name" text not null,"role" user_role not null default 'client'::user_role,"created_at" timestamp with time zone not null default timezone('utc'::text, now()));
create table public."program_members"("program_id" uuid not null,"user_id" uuid not null,"joined_at" timestamp with time zone not null default timezone('utc'::text, now()));
create table public."programs"("id" uuid not null default gen_random_uuid(),"coach_id" uuid not null,"name" text not null,"invite_code" text not null,"created_at" timestamp with time zone not null default timezone('utc'::text, now()),"kind" program_kind not null default 'group'::program_kind,"description" text not null default ''::text,"updated_at" timestamp with time zone not null default timezone('utc'::text, now()));
create table public."workout_assignments"("workout_id" uuid not null,"program_id" uuid not null,"assigned_at" timestamp with time zone not null default timezone('utc'::text, now()));
create table public."workout_parts"("id" uuid not null default gen_random_uuid(),"workout_id" uuid not null,"type" workout_part_type,"title" text not null,"description" text not null default ''::text,"sort_order" integer not null default 0,"score_type" text default 'text'::text);
create table public."workout_template_parts"("id" uuid not null default gen_random_uuid(),"template_id" uuid not null,"type" workout_part_type not null,"title" text not null,"description" text not null default ''::text,"sort_order" integer not null default 0,"score_type" text not null default 'text'::text);
create table public."workout_templates"("id" uuid not null default gen_random_uuid(),"coach_id" uuid not null,"title" text not null,"description" text not null default ''::text,"created_at" timestamp with time zone not null default timezone('utc'::text, now()),"updated_at" timestamp with time zone not null default timezone('utc'::text, now()));
create table public."workout_views"("workout_id" uuid not null,"user_id" uuid not null,"viewed_at" timestamp with time zone not null default now());
create table public."workouts"("id" uuid not null default gen_random_uuid(),"coach_id" uuid not null,"title" text not null,"description" text not null default ''::text,"scheduled_at" timestamp with time zone not null,"status" workout_status not null default 'draft'::workout_status,"created_at" timestamp with time zone not null default timezone('utc'::text, now()),"updated_at" timestamp with time zone not null default timezone('utc'::text, now()),"published_at" timestamp with time zone);
alter table public."program_members" add constraint "group_members_pkey" PRIMARY KEY (program_id, user_id);
alter table public."programs" add constraint "groups_pkey" PRIMARY KEY (id);
alter table public."part_results" add constraint "part_results_pkey" PRIMARY KEY (id);
alter table public."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);
alter table public."workout_assignments" add constraint "workout_assignments_pkey" PRIMARY KEY (workout_id, program_id);
alter table public."workout_parts" add constraint "workout_parts_pkey" PRIMARY KEY (id);
alter table public."workout_template_parts" add constraint "workout_template_parts_pkey" PRIMARY KEY (id);
alter table public."workout_templates" add constraint "workout_templates_pkey" PRIMARY KEY (id);
alter table public."workout_views" add constraint "workout_views_pkey" PRIMARY KEY (workout_id, user_id);
alter table public."workouts" add constraint "workouts_pkey" PRIMARY KEY (id);
alter table public."programs" add constraint "groups_invite_code_key" UNIQUE (invite_code);
alter table public."part_results" add constraint "part_results_part_id_user_id_key" UNIQUE (part_id, user_id);
alter table public."program_members" add constraint "group_members_group_id_fkey" FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE;
alter table public."program_members" add constraint "group_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."programs" add constraint "groups_coach_id_fkey" FOREIGN KEY (coach_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."part_results" add constraint "part_results_part_id_fkey" FOREIGN KEY (part_id) REFERENCES workout_parts(id) ON DELETE CASCADE;
alter table public."part_results" add constraint "part_results_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."part_results" add constraint "part_results_workout_id_fkey" FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE;
alter table public."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."workout_assignments" add constraint "workout_assignments_group_id_fkey" FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE;
alter table public."workout_assignments" add constraint "workout_assignments_workout_id_fkey" FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE;
alter table public."workout_parts" add constraint "workout_parts_workout_id_fkey" FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE;
alter table public."workout_template_parts" add constraint "workout_template_parts_template_id_fkey" FOREIGN KEY (template_id) REFERENCES workout_templates(id) ON DELETE CASCADE;
alter table public."workout_templates" add constraint "workout_templates_coach_id_fkey" FOREIGN KEY (coach_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."workout_views" add constraint "workout_views_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."workout_views" add constraint "workout_views_workout_id_fkey" FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE;
alter table public."workouts" add constraint "workouts_coach_id_fkey" FOREIGN KEY (coach_id) REFERENCES profiles(id) ON DELETE CASCADE;
set check_function_bodies=off;
CREATE OR REPLACE FUNCTION private.is_program_member(p_program_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.program_members WHERE program_id = p_program_id AND user_id = p_user_id
  );
$function$;

CREATE OR REPLACE FUNCTION private.is_program_coach(p_program_id uuid, p_coach_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.programs WHERE id = p_program_id AND coach_id = p_coach_id
  );
$function$;

CREATE OR REPLACE FUNCTION private.can_user_view_workout(p_workout_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.workouts WHERE id = p_workout_id AND coach_id = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.workouts w
    JOIN public.workout_assignments wa ON wa.workout_id = w.id
    JOIN public.program_members pm ON pm.program_id = wa.program_id
    WHERE w.id = p_workout_id AND w.status = 'published' AND pm.user_id = p_user_id
  );
$function$;

CREATE OR REPLACE FUNCTION private.is_template_coach(template_uuid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workout_templates
    WHERE id = template_uuid
      AND coach_id = auth.uid()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION private.is_group_member(p_group_id uuid, p_user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members WHERE group_id = p_group_id AND user_id = p_user_id
  );
$function$;

CREATE OR REPLACE FUNCTION private.is_group_coach(p_group_id uuid, p_coach_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.groups WHERE id = p_group_id AND coach_id = p_coach_id
  );
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Спортсмен'),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'client'::public.user_role)
  );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_workout_published_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_part_result(p_operation_id uuid, p_result_id uuid, p_workout_id uuid, p_part_id uuid, p_client_updated_at timestamp with time zone, p_deleted boolean, p_status result_status DEFAULT 'done'::result_status, p_score_type text DEFAULT 'text'::text, p_score_text text DEFAULT ''::text, p_time_ms bigint DEFAULT NULL::bigint, p_rounds integer DEFAULT NULL::integer, p_reps integer DEFAULT NULL::integer, p_weight_kg numeric DEFAULT NULL::numeric, p_distance_m numeric DEFAULT NULL::numeric, p_calories integer DEFAULT NULL::integer, p_note text DEFAULT ''::text)
 RETURNS part_results
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_result public.part_results;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.part_results (
    id, workout_id, part_id, user_id, status, score_type, score_text,
    time_ms, rounds, reps, weight_kg, distance_m, calories, note,
    client_updated_at, last_operation_id, deleted_at, updated_at
  ) values (
    p_result_id, p_workout_id, p_part_id, v_user_id, p_status, p_score_type,
    p_score_text, p_time_ms, p_rounds, p_reps, p_weight_kg, p_distance_m,
    p_calories, p_note, p_client_updated_at, p_operation_id,
    case when p_deleted then p_client_updated_at else null end, now()
  )
  on conflict (part_id, user_id) do update set
    status = excluded.status,
    score_type = excluded.score_type,
    score_text = excluded.score_text,
    time_ms = excluded.time_ms,
    rounds = excluded.rounds,
    reps = excluded.reps,
    weight_kg = excluded.weight_kg,
    distance_m = excluded.distance_m,
    calories = excluded.calories,
    note = excluded.note,
    client_updated_at = excluded.client_updated_at,
    last_operation_id = excluded.last_operation_id,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  where (excluded.client_updated_at, excluded.last_operation_id::text) >
        (part_results.client_updated_at, part_results.last_operation_id::text);

  select * into v_result
  from public.part_results
  where part_id = p_part_id and user_id = v_user_id;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_program_by_code(code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_user_role public.user_role;
  v_program_id uuid;
  v_program_name text;
  v_program_kind public.program_kind;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select role
  into v_user_role
  from public.profiles
  where id = v_user_id;

  if v_user_role is distinct from 'client'::public.user_role then
    raise exception 'Only clients can join programs' using errcode = '42501';
  end if;

  select id, name, kind
  into v_program_id, v_program_name, v_program_kind
  from public.programs
  where upper(invite_code) = upper(trim(code));

  if v_program_id is null then
    raise exception 'Программа с кодом % не найдена', code;
  end if;

  insert into public.program_members (program_id, user_id)
  values (v_program_id, v_user_id)
  on conflict (program_id, user_id) do nothing;

  return json_build_object(
    'id', v_program_id,
    'name', v_program_name,
    'kind', v_program_kind
  );
end;
$function$;

set check_function_bodies=on;
alter table public."part_results" enable row level security;
alter table public."profiles" enable row level security;
alter table public."program_members" enable row level security;
alter table public."programs" enable row level security;
alter table public."workout_assignments" enable row level security;
alter table public."workout_parts" enable row level security;
alter table public."workout_template_parts" enable row level security;
alter table public."workout_templates" enable row level security;
alter table public."workout_views" enable row level security;
alter table public."workouts" enable row level security;
create policy "Clients can create own results" on public."part_results" for INSERT to "authenticated" with check ((user_id = auth.uid()));
create policy "Clients can delete own results" on public."part_results" for DELETE to "authenticated" using ((user_id = auth.uid()));
create policy "Clients can update own results" on public."part_results" for UPDATE to "authenticated" using ((user_id = auth.uid())) with check ((user_id = auth.uid()));
create policy "Users can view results for assigned workouts" on public."part_results" for SELECT to "authenticated" using (((user_id = auth.uid()) OR private.can_user_view_workout(workout_id, auth.uid())));
create policy "Authenticated users can read profiles" on public."profiles" for SELECT to "authenticated" using (true);
create policy "Users can update own profile" on public."profiles" for UPDATE to "authenticated" using ((auth.uid() = id));
create policy "Member can leave or coach can remove member" on public."program_members" for DELETE to "authenticated" using (((user_id = auth.uid()) OR private.is_program_coach(program_id, auth.uid())));
create policy "Program members and coach can read membership" on public."program_members" for SELECT to "authenticated" using ((private.is_program_coach(program_id, auth.uid()) OR private.is_program_member(program_id, auth.uid())));
create policy "Coach and members can read programs" on public."programs" for SELECT to "authenticated" using (((coach_id = auth.uid()) OR private.is_program_member(id, auth.uid())));
create policy "Coach can create programs" on public."programs" for INSERT to "authenticated" with check ((coach_id = auth.uid()));
create policy "Coach can delete own programs" on public."programs" for DELETE to "authenticated" using ((coach_id = auth.uid()));
create policy "Coach can update own programs" on public."programs" for UPDATE to "authenticated" using ((coach_id = auth.uid())) with check ((coach_id = auth.uid()));
create policy "Coach can assign workout to own program" on public."workout_assignments" for INSERT to "authenticated" with check (((EXISTS ( SELECT 1
   FROM workouts w
  WHERE ((w.id = workout_assignments.workout_id) AND (w.coach_id = auth.uid())))) AND private.is_program_coach(program_id, auth.uid())));
create policy "Coach can delete workout assignments" on public."workout_assignments" for DELETE to "authenticated" using ((EXISTS ( SELECT 1
   FROM workouts w
  WHERE ((w.id = workout_assignments.workout_id) AND (w.coach_id = auth.uid())))));
create policy "Coach or members can view workout assignments" on public."workout_assignments" for SELECT to "authenticated" using (((EXISTS ( SELECT 1
   FROM workouts w
  WHERE ((w.id = workout_assignments.workout_id) AND (w.coach_id = auth.uid())))) OR private.is_program_member(program_id, auth.uid())));
create policy "Coach can manage workout parts" on public."workout_parts" for ALL to "authenticated" using ((workout_id IN ( SELECT workouts.id
   FROM workouts
  WHERE (workouts.coach_id = auth.uid())))) with check ((workout_id IN ( SELECT workouts.id
   FROM workouts
  WHERE (workouts.coach_id = auth.uid()))));
create policy "Users can view workout parts of visible workouts" on public."workout_parts" for SELECT to "authenticated" using (private.can_user_view_workout(workout_id, auth.uid()));
create policy "Coach can create own template parts" on public."workout_template_parts" for INSERT to public with check (private.is_template_coach(template_id));
create policy "Coach can delete own template parts" on public."workout_template_parts" for DELETE to public using (private.is_template_coach(template_id));
create policy "Coach can update own template parts" on public."workout_template_parts" for UPDATE to public using (private.is_template_coach(template_id));
create policy "Coach can view own template parts" on public."workout_template_parts" for SELECT to public using (private.is_template_coach(template_id));
create policy "Coach can create own templates" on public."workout_templates" for INSERT to public with check ((coach_id = auth.uid()));
create policy "Coach can delete own templates" on public."workout_templates" for DELETE to public using ((coach_id = auth.uid()));
create policy "Coach can update own templates" on public."workout_templates" for UPDATE to public using ((coach_id = auth.uid()));
create policy "Coach can view own templates" on public."workout_templates" for SELECT to public using ((coach_id = auth.uid()));
create policy "Clients can create own workout views" on public."workout_views" for INSERT to "authenticated" with check (((user_id = auth.uid()) AND private.can_user_view_workout(workout_id, auth.uid())));
create policy "Clients can update own workout views" on public."workout_views" for UPDATE to "authenticated" using ((user_id = auth.uid())) with check (((user_id = auth.uid()) AND private.can_user_view_workout(workout_id, auth.uid())));
create policy "Clients can view own workout views" on public."workout_views" for SELECT to "authenticated" using ((user_id = auth.uid()));
create policy "Clients can read published workouts assigned to their groups" on public."workouts" for SELECT to "authenticated" using (private.can_user_view_workout(id, auth.uid()));
create policy "Coach can manage workouts" on public."workouts" for ALL to "authenticated" using ((coach_id = auth.uid())) with check ((coach_id = auth.uid()));
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
CREATE TRIGGER set_workout_published_at BEFORE INSERT OR UPDATE OF status ON public.workouts FOR EACH ROW EXECUTE FUNCTION set_workout_published_at();

grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.programs,public.workouts,public.workout_parts,public.part_results to authenticated;
grant select,delete on public.program_members to authenticated;
grant select,insert,delete on public.workout_assignments to authenticated;
grant select,insert,update on public.workout_views to authenticated;
revoke all on all functions in schema private from public,anon;
grant execute on all functions in schema private to authenticated;
revoke all on function public.handle_new_user(),public.join_program_by_code(text), public.sync_part_result(uuid,uuid,uuid,uuid,timestamptz,boolean,public.result_status,text,text,bigint,integer,integer,numeric,numeric,integer,text) from public, anon;
grant execute on function public.join_program_by_code(text), public.sync_part_result(uuid,uuid,uuid,uuid,timestamptz,boolean,public.result_status,text,text,bigint,integer,integer,numeric,numeric,integer,text) to authenticated;
