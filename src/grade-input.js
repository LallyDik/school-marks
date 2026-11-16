export function normalizeGrade(value){
 const text=value.trim().replace(/\s/g,'').replace(/[−–—]/g,'-');
 return /^\d-\d$/.test(text)?text.replace('-','–'):text;
}
