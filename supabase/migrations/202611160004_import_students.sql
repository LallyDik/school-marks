begin;
create function public.import_students(p_year uuid,p_rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb; c uuid; s uuid; current_class uuid; starts date;
 created_students integer:=0; created_classes integer:=0; enrolled integer:=0;
begin
 if not public.is_admin() then raise exception 'Administrator required'; end if;
 select starts_on into strict starts from public.school_years where id=p_year and not archived for update;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)=0 or jsonb_array_length(p_rows)>2000 then raise exception 'Invalid import size'; end if;
 if exists(select 1 from jsonb_array_elements(p_rows) x group by x->>'identity_number' having count(*)>1) then raise exception 'Duplicate identity numbers in import'; end if;
 for r in select * from jsonb_array_elements(p_rows) loop
  if coalesce(r->>'identity_number','')!~'^\d{9}$' or length(trim(coalesce(r->>'first_name','')))=0 or length(trim(coalesce(r->>'last_name','')))=0 or length(trim(coalesce(r->>'class_name','')))=0 or coalesce((r->>'grade_level')::integer,0) not between 1 and 12 then raise exception 'Invalid student row'; end if;
  select id into c from public.classes where year_id=p_year and name=r->>'class_name';
  if c is null then
   insert into public.classes(year_id,name,grade_level) values(p_year,r->>'class_name',(r->>'grade_level')::integer) returning id into c;
   created_classes:=created_classes+1;
  elsif not exists(select 1 from public.classes where id=c and grade_level=(r->>'grade_level')::integer) then raise exception 'Existing class has a different grade level';
  end if;
  select id into s from public.students where identity_number=r->>'identity_number' for update;
  if s is null then
   insert into public.students(first_name,last_name,identity_number) values(trim(r->>'first_name'),trim(r->>'last_name'),r->>'identity_number') returning id into s;
   created_students:=created_students+1;
  end if;
  select class_id into current_class from public.enrollments where student_id=s and year_id=p_year and ends_on is null;
  if current_class is not null and current_class<>c then raise exception 'Student % is already assigned to another class; use class transfer first',r->>'identity_number'; end if;
  if current_class is null then
   if exists(select 1 from public.enrollments where student_id=s and year_id=p_year) then raise exception 'Student has historical enrollment; use class transfer'; end if;
   insert into public.enrollments(student_id,year_id,class_id,starts_on) values(s,p_year,c,starts);
   enrolled:=enrolled+1;
  end if;
 end loop;
 return jsonb_build_object('students_created',created_students,'classes_created',created_classes,'enrolled',enrolled);
end; $$;
revoke all on function public.import_students(uuid,jsonb) from public,anon;
grant execute on function public.import_students(uuid,jsonb) to authenticated;
commit;
