begin;
create function public.homeroom_group(g uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.active_staff() and exists(
 select 1 from public.study_groups sg join public.group_students gs on gs.group_id=sg.id
 join public.enrollments e on e.student_id=gs.student_id and e.year_id=sg.year_id and e.ends_on is null
 join public.classes c on c.id=e.class_id
 where sg.id=g and c.homeroom_teacher_id=auth.uid());
$$;
create policy homeroom_groups on public.study_groups for select to authenticated using(public.homeroom_group(id));
create policy homeroom_members on public.group_students for select to authenticated using(
 public.homeroom_student(student_id,(select year_id from public.study_groups where id=group_id)));
create policy homeroom_grade_insert on public.grades for insert to authenticated with check(public.homeroom_student(student_id,year_id));
create policy homeroom_grade_update on public.grades for update to authenticated
 using(public.homeroom_student(student_id,year_id)) with check(public.homeroom_student(student_id,year_id));
commit;
