import ExcelJS from 'exceljs';
const clean=v=>String(v??'').trim().replace(/\s+/g,' ');
const header=v=>clean(v).replace(/[.׳״'"\s]/g,'');
export function classInfo(value){
 const s=clean(value).replace(/^כ(?:י)?תה\s*/, '').replace(/[׳״'"\s]/g,'');
 const match=s.match(/^(יב|יא|י|ט|ח|ז|ו|ה|ד|ג|ב|א|12|11|10|[1-9])(\d*)$/);
 if(!match)return null;
 const levels=['א','ב','ג','ד','ה','ו','ז','ח','ט','י','יא','יב'];
 const level=/^\d+$/.test(match[1])?Number(match[1]):levels.indexOf(match[1])+1;
 return {class_name:`${levels[level-1]}${match[2]?'׳ '+match[2]:'׳'}`,grade_level:level};
}
export async function readStudents(buffer){
 const workbook=new ExcelJS.Workbook();await workbook.xlsx.load(buffer);
 const rows=[];const warnings=[];const seen=new Set();
 for(const sheet of workbook.worksheets){
  let columns=null;
  sheet.eachRow((row,number)=>{
   const cells=Array.from({length:row.cellCount},(_,i)=>{const cell=row.getCell(i+1);return cell.value===null?'':clean(cell.text)});
   const nameIndex=cells.findIndex(c=>['שם','שםהתלמידה','שםמלא'].includes(header(c)));
   const idIndex=cells.findIndex(c=>['תז','מז','מספרזהות','מסזהות'].includes(header(c)));
   if(nameIndex>=0&&idIndex>=0){columns={name:nameIndex,id:idIndex,class:cells.findIndex(c=>['כתה','כיתה'].includes(header(c)))};return;}
   if(!columns||!cells[columns.name]||/^כ(?:י)?תה/.test(cells[columns.name]))return;
   const fullname=cells[columns.name];const raw=cells[columns.id]||'';
   if(!raw&&!cells[columns.class])return;
   const id=raw.replace(/[-\s]/g,'').padStart(9,'0');
   const info=classInfo(cells[columns.class]);
   if(!/^\d{9}$/.test(id)||!raw||!info){warnings.push(`${sheet.name}, שורה ${number}: יש לבדוק מספר זהות וכיתה.`);return;}
   if(seen.has(id)){warnings.push(`${sheet.name}, שורה ${number}: מספר זהות כפול בקובץ.`);return;}seen.add(id);
   const parts=fullname.split(' ');
   rows.push({identity_number:id,last_name:parts.shift(),first_name:parts.join(' '),...info,source_row:number});
  });
 }
 return {rows,warnings};
}
