begin;
alter table public.study_groups add column class_id uuid;
alter table public.study_groups add constraint teaching_class_year foreign key(class_id,year_id) references public.classes(id,year_id);
create unique index one_class_subject on public.study_groups(class_id,subject_id) where class_id is not null;

create function public.assign_class_subject(p_class uuid,p_subject uuid,p_teacher uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare c public.classes; g uuid; subject_name text;
begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 select * into strict c from public.classes where id=p_class for update;
 if not exists(select 1 from public.school_years where id=c.year_id and not archived) then raise exception 'Year is archived'; end if;
 if not exists(select 1 from public.staff where id=p_teacher and active) then raise exception 'Teacher must be active'; end if;
 select name into strict subject_name from public.subjects where id=p_subject;
 select id into g from public.study_groups where class_id=p_class and subject_id=p_subject;
 if g is null then
  insert into public.study_groups(year_id,subject_id,name,class_id)
  values(c.year_id,p_subject,c.name||' — '||subject_name,p_class) returning id into g;
 end if;
 insert into public.group_teachers(group_id,teacher_id) values(g,p_teacher) on conflict do nothing;
 insert into public.group_students(group_id,student_id)
 select g,student_id from public.enrollments where class_id=p_class and year_id=c.year_id and ends_on is null on conflict do nothing;
 return g;
end; $$;
revoke all on function public.assign_class_subject(uuid,uuid,uuid) from public,anon;
grant execute on function public.assign_class_subject(uuid,uuid,uuid) to authenticated;

create function public.sync_class_teaching() returns trigger language plpgsql security definer set search_path='' as $$
declare s uuid; y uuid;
begin
 if tg_op<>'INSERT' then
  s:=old.student_id; y:=old.year_id;
  delete from public.grade_submissions where group_id in(select id from public.study_groups where year_id=y and class_id is not null);
  delete from public.group_students gs using public.study_groups g
  where gs.group_id=g.id and gs.student_id=s and g.year_id=y and g.class_id is not null
  and not exists(select 1 from public.enrollments e where e.student_id=s and e.class_id=g.class_id and e.year_id=y and e.ends_on is null);
 end if;
 if tg_op<>'DELETE' then
  s:=new.student_id;y:=new.year_id;
  delete from public.grade_submissions where group_id in(select id from public.study_groups where year_id=y and class_id=new.class_id);
  insert into public.group_students(group_id,student_id)
  select g.id,s from public.study_groups g join public.enrollments e on e.class_id=g.class_id and e.year_id=g.year_id
  where g.class_id is not null and g.year_id=y and e.student_id=s and e.ends_on is null on conflict do nothing;
 end if;
 return coalesce(new,old);
end; $$;
create trigger sync_class_teaching after insert or update or delete on public.enrollments for each row execute function public.sync_class_teaching();
commit;
