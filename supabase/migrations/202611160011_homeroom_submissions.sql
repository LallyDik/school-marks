begin;
create function public.can_submit_homeroom(g uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.active_staff() and exists(select 1 from public.study_groups sg join public.classes c on c.id=sg.class_id and c.year_id=sg.year_id where sg.id=g and c.homeroom_teacher_id=auth.uid());
$$;
create policy homeroom_submissions_read on public.grade_submissions for select to authenticated using(public.can_submit_homeroom(group_id));
create policy homeroom_submissions_insert on public.grade_submissions for insert to authenticated with check(public.can_submit_homeroom(group_id) and submitted_by=auth.uid());
commit;
