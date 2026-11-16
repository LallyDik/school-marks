begin;
create function public.check_teaching_role() returns trigger language plpgsql security definer set search_path='' as $$
declare teacher uuid;
begin
 if tg_table_name='classes' then teacher:=new.homeroom_teacher_id; else teacher:=new.teacher_id; end if;
 if teacher is not null and exists(select 1 from public.staff where id=teacher and is_admin) then
  raise exception 'מנהלת אינה מורה מלמדת. יש לבחור מורה מצוות ההוראה.';
 end if;
 return new;
end; $$;
create trigger check_class_teaching_role before insert or update of homeroom_teacher_id on public.classes for each row execute function public.check_teaching_role();
create trigger check_subject_teaching_role before insert or update of teacher_id on public.group_teachers for each row execute function public.check_teaching_role();
commit;
