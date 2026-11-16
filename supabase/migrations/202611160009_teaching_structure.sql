begin;
-- Class subjects and grade-level ability groups are separate domain entities.
-- Existing IDs remain stable so recorded grades retain their provenance.
alter table public.study_groups add column grade_level smallint check(grade_level between 1 and 12);
alter table public.study_groups add constraint separate_teaching_scopes check(class_id is null or grade_level is null);
create view public.class_subjects with(security_invoker=true) as
 select g.id,g.year_id,g.class_id,g.subject_id,g.name from public.study_groups g where g.class_id is not null;
create view public.ability_groups with(security_invoker=true) as
 select g.id,g.year_id,g.grade_level,g.subject_id,g.name from public.study_groups g where g.class_id is null;
grant select on public.class_subjects,public.ability_groups to authenticated;

create function public.set_subject_teacher(p_group uuid,p_teacher uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 perform 1 from public.study_groups where id=p_group for update;
 if not found then raise exception 'Teaching assignment not found'; end if;
 if not exists(select 1 from public.staff where id=p_teacher and active) then raise exception 'Teacher must be active'; end if;
 delete from public.group_teachers where group_id=p_group and teacher_id<>p_teacher;
 insert into public.group_teachers values(p_group,p_teacher) on conflict do nothing;
end; $$;
revoke all on function public.set_subject_teacher(uuid,uuid) from public,anon;
grant execute on function public.set_subject_teacher(uuid,uuid) to authenticated;

create function public.check_ability_membership() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.study_groups; begin
 select * into strict g from public.study_groups where id=new.group_id;
 if g.class_id is null and g.grade_level is not null then
  if not exists(select 1 from public.enrollments e join public.classes c on c.id=e.class_id
   where e.student_id=new.student_id and e.year_id=g.year_id and e.ends_on is null and c.grade_level=g.grade_level)
  then raise exception 'Student must belong to the ability group grade level'; end if;
  if exists(select 1 from public.group_students m join public.study_groups other on other.id=m.group_id
   where m.student_id=new.student_id and other.id<>g.id and other.class_id is null and other.year_id=g.year_id and other.grade_level=g.grade_level and other.subject_id=g.subject_id)
  then raise exception 'Student already belongs to another ability group for this subject'; end if;
 end if;
 return new;
end; $$;
create trigger check_ability_membership before insert or update on public.group_students for each row execute function public.check_ability_membership();
commit;
