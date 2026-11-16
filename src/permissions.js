export function homeroomStudents({profile,year,classes,enrollments,students}) {
 if(profile?.is_admin)return students;
 const classIds=new Set(classes.filter(c=>c.year_id===year&&c.homeroom_teacher_id===profile?.id).map(c=>c.id));
 const studentIds=new Set(enrollments.filter(e=>e.year_id===year&&!e.ends_on&&classIds.has(e.class_id)).map(e=>e.student_id));
 return students.filter(s=>studentIds.has(s.id));
}
export function canOpenPage(page,profile,year,classes){
 if(profile?.is_admin)return true;
 if(page==='evaluations')return classes.some(c=>c.year_id===year&&c.homeroom_teacher_id===profile?.id);
 return ['dashboard','grades','my_subjects'].includes(page);
}
