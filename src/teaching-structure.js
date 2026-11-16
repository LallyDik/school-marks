const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function classCurriculum({state,data,yearly,select,form,table}){
 const classes=yearly('classes');
 if(!classes.some(c=>c.id===state.curriculumClass))state.curriculumClass=classes[0]?.id;
 const selected=classes.find(c=>c.id===state.curriculumClass);
 const groups=yearly('study_groups').filter(g=>g.class_id===state.curriculumClass&&g.class_id);
 const assigned=new Set(groups.map(g=>g.subject_id));
 const available=data('subjects').filter(s=>!assigned.has(s.id));
 return '<p>לכל כיתה רשימת מקצועות משלה. בחרי כיתה כדי לנהל את המקצועות והמורות שלה.</p><div class="panel">'+select('curriculum-class','כיתה לניהול מקצועות',classes,'name',state.curriculumClass)+'</div>'+(!selected?'<p>יש ליצור כיתה בשנת הלימודים הנבחרת.</p>':`<h2>המקצועות של ${esc(selected.name)}</h2>`+(available.length?form('class-subject',`<input type="hidden" name="class_id" value="${esc(selected.id)}">`+select('subject_id','מקצוע להוספה לכיתה',available)+select('teacher_id','מורה מלמדת',data('staff').filter(s=>s.active&&!s.is_admin),'full_name'),'שיוך מקצוע לכיתה'):'<p>כל המקצועות שבמאגר כבר משויכים לכיתה זו. אפשר להוסיף מקצוע חדש למאגר למטה.</p>')+(groups.length?table(['מקצוע בכיתה','מורה מלמדת'],groups.map(g=>[esc(data('subjects').find(s=>s.id===g.subject_id)?.name),`<select aria-label="מורה מלמדת" data-subject-teacher="${g.id}"><option value="">טרם שובצה</option>${data('staff').filter(t=>t.active&&!t.is_admin).map(t=>`<option value="${t.id}" ${data('group_teachers').some(a=>a.group_id===g.id&&a.teacher_id===t.id)?'selected':''}>${esc(t.full_name)}</option>`).join('')}</select>`])):'<div class="panel empty">עדיין לא שויכו מקצועות לכיתה הזו.</div>'));
}
export function abilityGroups({data,yearly,select,field,form,table}){
 const groups=yearly('study_groups').filter(g=>!g.class_id);
 const levels=[...new Set(yearly('classes').map(c=>c.grade_level))].sort((a,b)=>a-b).map(level=>({id:level,name:['א','ב','ג','ד','ה','ו','ז','ח','ט','י','יא','יב'][level-1]}));
 return '<p>הקבצות הן חלוקה נוספת בתוך שנתון, במקצוע מסוים. השיוך להקבצה נפרד מכיתת האם.</p>'+form('ability-create',select('grade_level','שנתון',levels)+select('subject_id','מקצוע',data('subjects'))+field('name','שם ההקבצה','text','required')+select('teacher_id','מורה מלמדת',data('staff').filter(s=>s.active&&!s.is_admin),'full_name'),'יצירת הקבצה')+form('student-group',select('group_id','הקבצה',groups)+select('student_id','תלמידה',data('students'),s=>`${s.last_name} ${s.first_name}`),'שיוך תלמידה להקבצה')+table(['שנתון','הקבצה','מקצוע','מורה','תלמידות'],groups.map(g=>[g.grade_level??'טרם הוגדר',esc(g.name),esc(data('subjects').find(s=>s.id===g.subject_id)?.name),esc(data('staff').find(t=>data('group_teachers').some(a=>a.group_id===g.id&&a.teacher_id===t.id))?.full_name||'טרם שובצה'),data('group_students').filter(s=>s.group_id===g.id).length]));
}
