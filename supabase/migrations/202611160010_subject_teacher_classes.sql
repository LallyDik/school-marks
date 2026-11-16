begin;
create function public.teaches_class(c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.active_staff() and exists(select 1 from public.study_groups g join public.group_teachers t on t.group_id=g.id where g.class_id=c and t.teacher_id=auth.uid());
$$;
create policy subject_teacher_classes on public.classes for select to authenticated using(public.teaches_class(id));
commit;
