begin;
create function public.active_staff() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff where id=auth.uid() and active);
$$;
create function public.teaches_group(g uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.active_staff() and exists(select 1 from public.group_teachers where group_id=g and teacher_id=auth.uid());
$$;
create function public.homeroom_student(s uuid,y uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.active_staff() and exists(select 1 from public.enrollments e join public.classes c on c.id=e.class_id where e.student_id=s and e.year_id=y and e.ends_on is null and c.homeroom_teacher_id=auth.uid());
$$;
create function public.can_view_student(s uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.active_staff() and (exists(select 1 from public.group_students gs join public.group_teachers gt on gs.group_id=gt.group_id where gs.student_id=s and gt.teacher_id=auth.uid()) or exists(select 1 from public.enrollments e join public.classes c on c.id=e.class_id where e.student_id=s and c.homeroom_teacher_id=auth.uid()));
$$;
create policy teacher_years on public.school_years for select to authenticated using(public.active_staff());
create policy teacher_terms on public.terms for select to authenticated using(public.active_staff());
create policy teacher_subjects on public.subjects for select to authenticated using(public.active_staff());
create policy teacher_students on public.students for select to authenticated using(public.can_view_student(id));
create policy teacher_classes on public.classes for select to authenticated using(public.active_staff() and homeroom_teacher_id=auth.uid());
create policy teacher_enrollments on public.enrollments for select to authenticated using(public.can_view_student(student_id));
create policy teacher_groups on public.study_groups for select to authenticated using(public.teaches_group(id));
create policy teacher_assignments on public.group_teachers for select to authenticated using(public.active_staff() and teacher_id=auth.uid());
create policy teacher_members on public.group_students for select to authenticated using(public.teaches_group(group_id));
create policy teacher_grade_read on public.grades for select to authenticated using(public.teaches_group(group_id) or public.homeroom_student(student_id,year_id));
create policy teacher_grade_insert on public.grades for insert to authenticated with check(public.teaches_group(group_id));
create policy teacher_grade_update on public.grades for update to authenticated using(public.teaches_group(group_id)) with check(public.teaches_group(group_id));
create policy homeroom_evaluation_read on public.evaluations for select to authenticated using(public.homeroom_student(student_id,(select year_id from public.terms where id=term_id)));
create policy homeroom_evaluation_insert on public.evaluations for insert to authenticated with check(public.homeroom_student(student_id,(select year_id from public.terms where id=term_id)));
create policy homeroom_evaluation_update on public.evaluations for update to authenticated using(public.homeroom_student(student_id,(select year_id from public.terms where id=term_id))) with check(public.homeroom_student(student_id,(select year_id from public.terms where id=term_id)));
create table public.grade_submissions (
 group_id uuid not null references public.study_groups,
 term_id uuid not null references public.terms,
 submitted_by uuid not null default auth.uid() references public.staff,
 submitted_at timestamptz not null default now(), primary key(group_id,term_id)
);
alter table public.grade_submissions enable row level security;
create policy admin_submissions on public.grade_submissions for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy teacher_submissions_read on public.grade_submissions for select to authenticated using(public.teaches_group(group_id));
create policy teacher_submissions_insert on public.grade_submissions for insert to authenticated with check(public.teaches_group(group_id) and submitted_by=auth.uid());
create function public.validate_submission() returns trigger language plpgsql security definer set search_path='' as $$
declare y uuid; begin
 select year_id into strict y from public.terms where id=new.term_id and not locked;
 if not exists(select 1 from public.study_groups where id=new.group_id and year_id=y) then raise exception 'Invalid group year'; end if;
 if not exists(select 1 from public.group_students where group_id=new.group_id) then raise exception 'Group has no students'; end if;
 if exists(select 1 from public.group_students s where s.group_id=new.group_id and not exists(select 1 from public.grades g where g.group_id=s.group_id and g.student_id=s.student_id and g.term_id=new.term_id and g.grade_code is not null and g.assignments is not null)) then raise exception 'Some grades are missing'; end if;
 return new;
end; $$;
create trigger validate_submission before insert or update on public.grade_submissions for each row execute function public.validate_submission();
create function public.invalidate_submission() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'INSERT' then delete from public.grade_submissions where group_id=old.group_id and term_id=old.term_id; end if;
 if tg_op<>'DELETE' then delete from public.grade_submissions where group_id=new.group_id and term_id=new.term_id; end if;
 return coalesce(new,old);
end; $$;
create trigger invalidate_submission after insert or update or delete on public.grades for each row execute function public.invalidate_submission();
commit;
