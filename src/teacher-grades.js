const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function teachingGroups(state,onlyAssigned=false){
 const d=state.data;const assigned=new Set(d.group_teachers.filter(t=>t.teacher_id===state.profile.id).map(t=>t.group_id));
 const homeroom=new Set(d.classes.filter(c=>c.homeroom_teacher_id===state.profile.id).map(c=>c.id));
 return d.study_groups.filter(g=>g.year_id===state.year&&(state.profile.is_admin||assigned.has(g.id)||(!onlyAssigned&&homeroom.has(g.class_id))));
}
export function gradeProgress(group,term,data){
 const students=new Set(data.group_students.filter(s=>s.group_id===group.id).map(s=>s.student_id));
 const rows=data.grades.filter(g=>g.term_id===term&&g.subject_id===group.subject_id&&students.has(g.student_id));
 const complete=rows.filter(g=>g.grade_code&&g.assignments!=null).length;
 return {total:students.size,complete,partial:rows.filter(g=>!g.grade_code||g.assignments==null).length,missing:students.size-rows.length};
}
export function gradeSelectors(state,select){
 const groups=teachingGroups(state);const mode=state.gradeMode||'classes';
 let available=groups.filter(g=>mode==='classes'?!!g.class_id:!g.class_id);
 const classes=[...new Set(available.filter(g=>g.class_id).map(g=>g.class_id))].map(id=>({id,name:state.data.classes.find(c=>c.id===id)?.name||available.find(g=>g.class_id===id)?.name?.split(' — ')[0]||'כיתה'}));
 if(mode==='classes'){
  if(!classes.some(c=>c.id===state.gradeClass))state.gradeClass=classes[0]?.id;
  available=available.filter(g=>g.class_id===state.gradeClass);
 }
 if(!available.some(g=>g.id===state.group))state.group=available[0]?.id;
 const subjectLabel=g=>state.data.subjects.find(s=>s.id===g.subject_id)?.name||g.name;
 return `<div class="panel"><div class="actions" style="margin:0 0 20px"><button class="${mode==='classes'?'':'secondary'}" data-grade-mode="classes">ציוני כיתות</button><button class="${mode==='abilities'?'':'secondary'}" data-grade-mode="abilities">ציוני הקבצות</button></div><div class="form-grid">${mode==='classes'?select('grade-class','כיתה',classes,'name',state.gradeClass):''}${select('group-filter',mode==='classes'?'מקצוע בכיתה':'הקבצה',available,mode==='classes'?subjectLabel:g=>`${g.name} — ${subjectLabel(g)}`,state.group)}${select('term-filter','מחצית',state.data.terms.filter(t=>t.year_id===state.year),t=>`מחצית ${t.number===1?'א׳':'ב׳'}`,state.term)}</div>${!available.length?'<p>אין שיבוצים להצגה במסגרת זו. מנהלת בית הספר יכולה להגדיר את המורה המלמדת במסך מקצועות הכיתות או הקבצות.</p>':''}</div>`;
}
export function mySubjects(state,{select,table}){
 const terms=state.data.terms.filter(t=>t.year_id===state.year);if(!terms.some(t=>t.id===state.term))state.term=terms[0]?.id;
 return `<div class="panel">${select('term-filter','מחצית',terms,t=>`מחצית ${t.number===1?'א׳':'ב׳'}`,state.term)}</div><p>מעקב אחר המקצועות שאת מלמדת ומקצועות כיתת החינוך שלך. הנתונים מוצגים לפי המחצית הנבחרת.</p>`+table(['מסגרת','מקצוע','תלמידות','הוזן במלואו','חלקי','טרם הוזן','מצב',''],teachingGroups(state).map(g=>{
 const p=gradeProgress(g,state.term,state.data);const submitted=state.data.grade_submissions.some(s=>s.group_id===g.id&&s.term_id===state.term);
 return [esc(g.class_id?state.data.classes.find(c=>c.id===g.class_id)?.name||g.name:g.name),esc(state.data.subjects.find(s=>s.id===g.subject_id)?.name),p.total,p.complete,p.partial,p.missing,submitted?'סומנה השלמה':p.total&&p.complete===p.total?'כל הציונים הוזנו':p.complete||p.partial?'בתהליך':'טרם התחילה הזנה',`<button data-open-teaching="${g.id}">צפייה / הזנה</button>`];
 }));
}
