insert into public.academic_scale(code,sort_order)
values('9+',0)
on conflict(code) do nothing;
