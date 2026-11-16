begin;

create table public.staff (
  id uuid primary key references auth.users(id),
  full_name text not null,
  is_admin boolean not null default false,
  active boolean not null default true
);
create function public.is_admin() returns boolean language sql stable security definer
set search_path = '' as $$
 select exists(select 1 from public.staff where id = auth.uid() and is_admin and active);
$$;
create table public.school_years (
 id uuid primary key default gen_random_uuid(), name text not null unique,
 starts_on date not null, ends_on date not null, archived boolean not null default false,
 check (ends_on > starts_on)
);
create table public.terms (
 id uuid primary key default gen_random_uuid(), year_id uuid not null references public.school_years,
 number smallint not null check (number in (1,2)), locked boolean not null default false,
 unique(year_id,number), unique(id,year_id)
);
create table public.classes (
 id uuid primary key default gen_random_uuid(), year_id uuid not null references public.school_years,
 grade_level smallint not null check (grade_level between 1 and 12), name text not null,
 homeroom_teacher_id uuid references public.staff, unique(year_id,name), unique(id,year_id)
);
create table public.students (
 id uuid primary key default gen_random_uuid(), first_name text not null, last_name text not null,
 identity_number text unique, left_on date
);
create table public.enrollments (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students,
 year_id uuid not null references public.school_years, class_id uuid not null,
 starts_on date not null, ends_on date,
 foreign key(class_id,year_id) references public.classes(id,year_id),
 check(ends_on is null or ends_on >= starts_on)
);
create unique index one_current_class on public.enrollments(student_id,year_id) where ends_on is null;
create table public.subjects (id uuid primary key default gen_random_uuid(), name text not null unique);
create table public.study_groups (
 id uuid primary key default gen_random_uuid(), year_id uuid not null references public.school_years,
 subject_id uuid not null references public.subjects, name text not null,
 show_name_on_report boolean not null default false, unique(id,year_id)
);
create table public.group_teachers (
 group_id uuid not null references public.study_groups, teacher_id uuid not null references public.staff,
 primary key(group_id,teacher_id)
);
create table public.group_students (
 group_id uuid not null references public.study_groups, student_id uuid not null references public.students,
 primary key(group_id,student_id)
);
-- Fixed lookup values will be seeded only after the school approves both scales.
create table public.academic_scale (code text primary key, sort_order integer not null unique);
create table public.behavior_scale (code text primary key, sort_order integer not null unique);
create table public.grades (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students,
 year_id uuid not null references public.school_years, term_id uuid not null,
 subject_id uuid not null references public.subjects, group_id uuid not null,
 grade_code text references public.academic_scale, assignments smallint check(assignments between 1 and 100),
 foreign key(term_id,year_id) references public.terms(id,year_id),
 foreign key(group_id,year_id) references public.study_groups(id,year_id),
 unique(student_id,term_id,subject_id)
);
create table public.evaluations (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students,
 term_id uuid not null references public.terms,
 manners text references public.behavior_scale, rules text references public.behavior_scale,
 punctuality text references public.behavior_scale, community text references public.behavior_scale,
 conduct text references public.behavior_scale,
 late_count integer check(late_count >= 0), absence_count integer check(absence_count >= 0),
 general_comment text, unique(student_id,term_id)
);
create table public.audit_log (
 id bigint generated always as identity primary key, actor_id uuid references auth.users,
 occurred_at timestamptz not null default now(), table_name text not null,
 operation text not null, old_data jsonb, new_data jsonb
);
create function public.record_change() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
 insert into public.audit_log(actor_id,table_name,operation,old_data,new_data)
 values(auth.uid(),tg_table_name,tg_op,to_jsonb(old),to_jsonb(new));
 return coalesce(new,old);
end; $$;
create function public.check_term_lock() returns trigger language plpgsql set search_path = '' as $$
begin
 if exists(select 1 from public.terms where id in (
   case when tg_op <> 'INSERT' then old.term_id end,
   case when tg_op <> 'DELETE' then new.term_id end) and locked) then
   raise exception 'Term is locked. An administrator must reopen it before editing.';
 end if;
 return coalesce(new,old);
end; $$;
create trigger grades_lock before insert or update or delete on public.grades for each row execute function public.check_term_lock();
create trigger evaluations_lock before insert or update or delete on public.evaluations for each row execute function public.check_term_lock();
-- Initial milestone: admin access only. Teacher policies require assignment-aware tests.
do $$ declare t text; begin
 foreach t in array array['staff','school_years','terms','classes','students','enrollments','subjects','study_groups','group_teachers','group_students','grades','evaluations'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy admin_access on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())',t);
 execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.record_change()',t);
 end loop;
end $$;
alter table public.audit_log enable row level security;
create policy admin_read on public.audit_log for select to authenticated using(public.is_admin());
alter table public.academic_scale enable row level security;
alter table public.behavior_scale enable row level security;
create policy scale_read on public.academic_scale for select to authenticated using(true);
create policy scale_read on public.behavior_scale for select to authenticated using(true);
commit;
