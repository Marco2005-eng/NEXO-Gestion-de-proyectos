// Un campo date no conserva la hora del timestamp original.
// Si no cambia el día de Lima, conserva el timestamp; una fecha nueva vence
// al final de ese día, para no quedar antes del inicio previsto del mismo día.
export function taskDay(value:unknown):string {
 if(!value)return '';
 const text=String(value);if(/^\d{4}-\d{2}-\d{2}$/.test(text))return text;
 const date=new Date(text);if(Number.isNaN(date.getTime()))return '';
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(date);
 return ['year','month','day'].map(k=>parts.find(p=>p.type===k)?.value).join('-');
}
export function taskDueAt(value:string,current:unknown):string|null {
 if(!value)return null;
 if(/^\d{4}-\d{2}-\d{2}$/.test(value)){
   if(taskDay(current)===value)return String(current);
   const result=value+'T23:59:59.999-05:00';
   if(Number.isNaN(Date.parse(result))||taskDay(result)!==value)throw new Error('La fecha de entrega no es válida.');
   return result;
 }
 if(Number.isNaN(Date.parse(value)))throw new Error('La fecha de entrega no es válida.');
 return value;
}
export function saveError(error:{code?:string;message:string}):string {
 if(error.code==='23505')return 'Ya existe un registro con ese código.';
 if(error.code==='42501'||error.code==='PGRST116')return 'No tienes permiso para guardar este registro o tu acceso cambió. Actualiza la página.';
 if(error.code==='23514'&&error.message.includes('tasks'))return 'La fecha de entrega no puede ser anterior al inicio previsto de la tarea. Revisa también el avance (0 a 100 %).';
 if(error.code==='23503')return 'Uno de los datos seleccionados ya no está disponible. Actualiza la página.';
 return 'No se pudo guardar: '+error.message;
}
