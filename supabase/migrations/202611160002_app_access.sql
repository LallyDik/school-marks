begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table private.setup (singleton boolean primary key default true check(singleton), code uuid not null default gen_random_uuid(), claimed boolean not null default false);
insert into private.setup(singleton) values(true);

create function public.register_staff() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.staff(id,full_name,is_admin,active) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'full_name',''),'משתמשת חדשה'),false,false);
 return new;
end; $$;
create trigger register_staff after insert on auth.users for each row execute function public.register_staff();
insert into public.staff(id,full_name,is_admin,active)
select id,coalesce(nullif(raw_user_meta_data->>'full_name',''),'משתמשת חדשה'),false,false from auth.users
on conflict(id) do nothing;
create policy own_profile on public.staff for select to authenticated using(id=auth.uid());

create function public.claim_admin(p_code uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 perform 1 from private.setup where singleton for update;
 if exists(select 1 from public.staff where is_admin) then raise exception 'Administrator already exists'; end if;
 if not exists(select 1 from private.setup where code=p_code and not claimed) then raise exception 'Invalid setup code'; end if;
 update public.staff set is_admin=true,active=true where id=auth.uid();
 update private.setup set claimed=true where singleton;
end; $$;
revoke all on function public.claim_admin(uuid) from public,anon;
grant execute on function public.claim_admin(uuid) to authenticated;

create function public.transfer_student(p_student uuid,p_class uuid,p_date date) returns void language plpgsql security definer set search_path='' as $$
declare y uuid; begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 select year_id into strict y from public.classes where id=p_class;
 perform 1 from public.students where id=p_student for update;
 if exists(select 1 from public.enrollments where student_id=p_student and year_id=y and starts_on>=p_date) then raise exception 'Transfer date must follow existing enrollment'; end if;
 update public.enrollments set ends_on=p_date-1 where student_id=p_student and year_id=y and ends_on is null;
 insert into public.enrollments(student_id,year_id,class_id,starts_on) values(p_student,y,p_class,p_date);
end; $$;
revoke all on function public.transfer_student(uuid,uuid,date) from public,anon;
grant execute on function public.transfer_student(uuid,uuid,date) to authenticated;

create function public.validate_grade() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.study_groups where id=new.group_id and subject_id=new.subject_id and year_id=new.year_id) then raise exception 'Group and subject do not match'; end if;
 if not exists(select 1 from public.group_students where group_id=new.group_id and student_id=new.student_id) then raise exception 'Student is not assigned to group'; end if;
 return new;
end; $$;
create trigger validate_grade before insert or update on public.grades for each row execute function public.validate_grade();
commit;
-- Copy the returned one-time code into the website after signing up.
select code as one_time_setup_code from private.setup where not claimed;
