import {readStudents} from './import-students';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function mountImport({db,state,refresh}){
 const host=document.createElement('section');host.className='panel';
 host.innerHTML='<h2>ייבוא תלמידות וכיתות מאקסל</h2><p>בחרי את קובץ התלמידות. הכיתות ייווצרו והשיבוץ יתבצע אוטומטית בשנת הלימודים הנבחרת. לפני השמירה אפשר לבדוק ולתקן שמות.</p><label>קובץ Excel<input type="file" accept=".xlsx" id="student-file"></label><div id="import-preview"></div>';
 document.querySelector('main h1').after(host);
 const output=host.querySelector('#import-preview');
 host.querySelector('input').onchange=async e=>{
  const file=e.target.files[0];if(!file)return;
  if(file.size>10*1024*1024){output.textContent='יש לבחור קובץ עד 10MB.';return;}
  output.textContent='קורא את הקובץ…';
  try{
   const parsed=await readStudents(await file.arrayBuffer());
   const existing=new Set((state.data.students||[]).map(s=>s.identity_number));
   output.innerHTML=`<p>נמצאו ${parsed.rows.length} תלמידות ב־${new Set(parsed.rows.map(r=>r.class_name)).size} כיתות. ${parsed.rows.filter(r=>existing.has(r.identity_number)).length} תלמידות כבר קיימות וייעשה שימוש ברשומות שלהן.</p><p>הקובץ מציג שם משפחה לפני שם פרטי. אפשר לתקן את החלוקה כאן.</p>${parsed.warnings.length?`<div class="notice error">${parsed.warnings.map(esc).join('<br>')}<br>יש לתקן את הקובץ ולהעלות שוב לפני הייבוא.</div>`:''}<div class="table-wrap" style="max-height:450px"><table><thead><tr><th>שם משפחה</th><th>שם פרטי</th><th>מספר זהות</th><th>כיתה</th></tr></thead><tbody>${parsed.rows.map((r,i)=>`<tr><td><input aria-label="שם משפחה שורה ${i+1}" data-index="${i}" data-key="last_name" value="${esc(r.last_name)}"></td><td><input aria-label="שם פרטי שורה ${i+1}" data-index="${i}" data-key="first_name" value="${esc(r.first_name)}"></td><td>${esc(r.identity_number)}</td><td>${esc(r.class_name)}</td></tr>`).join('')}</tbody></table></div><p>תלמידה שקיימת כבר בכיתה אחרת לא תועבר אוטומטית. הנתונים יישמרו יחד, ורק אם כל הייבוא תקין.</p><button id="confirm-import" ${!parsed.rows.length||parsed.warnings.length?'disabled':''}>ייבוא ושיוך לשנה הנבחרת</button><div id="import-status" role="status"></div>`;
   if(parsed.warnings.length){const warning=output.querySelector('.notice');warning.lastChild.textContent='אפשר לתקן את הקובץ ולהעלות מחדש, או לאשר דילוג על השורות האלה.';const consent=document.createElement('label');consent.innerHTML='<span><input type="checkbox" style="width:auto"> אני מאשרת לייבא רק את השורות התקינות ולדלג על השורות שפורטו למעלה</span>';warning.after(consent);consent.querySelector('input').onchange=e=>{output.querySelector('#confirm-import').disabled=!e.target.checked||!parsed.rows.length};}
   output.querySelectorAll('[data-index]').forEach(input=>input.oninput=()=>{parsed.rows[Number(input.dataset.index)][input.dataset.key]=input.value.trim()});
   output.querySelector('#confirm-import').onclick=async e=>{
    const status=output.querySelector('#import-status');
    if(!state.year){status.textContent='בחרי או צרי שנת לימודים לפני השמירה.';return;}
    if(parsed.rows.some(r=>!r.first_name||!r.last_name)){status.textContent='יש למלא שם פרטי ושם משפחה בכל שורה.';return;}
    e.target.disabled=true;host.querySelector('input[type=file]').disabled=true;status.textContent='שומר את התלמידות והכיתות…';
    const {data,error}=await db.rpc('import_students',{p_year:state.year,p_rows:parsed.rows.map(({source_row,...r})=>r)});
    if(error){status.textContent=error.code==='PGRST202'?'נדרש להתקין את עדכון ייבוא התלמידות בבסיס הנתונים.':error.message;e.target.disabled=false;host.querySelector('input[type=file]').disabled=false;return;}
    await refresh();const message=document.createElement('div');message.className='notice';message.textContent=`הייבוא הושלם: ${data.students_created} תלמידות חדשות, ${data.classes_created} כיתות חדשות ו־${data.enrolled} שיוכים לשנה.`;document.querySelector('main h1').after(message);
   };
  }catch(error){output.textContent='לא ניתן לקרוא את הקובץ. ודאי שזהו קובץ XLSX תקין.';}
 };
}
