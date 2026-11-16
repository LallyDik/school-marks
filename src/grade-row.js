const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function gradeCells(id,grade,locked){
 const saved=!!grade;
 const complete=!!grade?.grade_code&&grade?.assignments!=null;
 const disabled=locked||saved?'disabled':'';
 return [
 `<input class="grade-number" aria-label="ציון" id="grade-${id}" dir="ltr" type="text" maxlength="5" placeholder="8+" value="${esc(grade?.grade_code)}" ${disabled}>`,
 `<input class="grade-number" aria-label="עמידה במטלות" id="assignment-${id}" dir="ltr" type="number" min="1" max="100" value="${grade?.assignments??''}" ${disabled}>`,
 `<div class="grade-actions">${saved?`<span class="badge ${complete?'':'partial'}">${complete?'הוזן ✓':'הוזן חלקית'}</span>`:'<span class="muted">טרם הוזן</span>'}<button data-grade="${id}" ${saved?'hidden':''} ${locked?'disabled':''}>שמירה</button>${saved&&!locked?`<button class="secondary" data-edit-grade="${id}">שינוי</button><button class="secondary" data-cancel-grade="${id}" hidden>ביטול</button>`:''}${locked?'<span class="muted">מחצית נעולה</span>':''}</div>`
 ];
}
