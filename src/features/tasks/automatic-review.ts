import type {Row} from '@/features/workspace/domain/types';
export type ReviewCheck={id:string;title:string;observation:boolean;detail:string};
const stopwords=new Set('para como esta este esto estas estos tarea tareas realizar realizado realizada realizarse cumplir cumplido cumplirlo trabajo trabajos los las del una uno unos unas con por que sus sobre desde hasta entre mediante segun tambien todo todos todas debe deben sido tiene tienen hacer hice hemos'.split(' '));
function words(text:string):string[]{return text.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().match(/[a-z0-9]+/g)??[];}
/** Controles orientativos de los datos; no certifican el contenido de la evidencia. */
export function automaticReview(submission:Row,evidence:Row[]):ReviewCheck[]{
 const summary=String(submission.summary??'').trim();const criteria=String(submission.criteria_snapshot??'').trim();
 const descriptionWords=words(summary);const requested=submission.requested_progress;const percent=requested==null?NaN:Number(requested);
 const referenceWords=[...new Set(words(criteria).filter(w=>w.length>=3&&!stopwords.has(w)))];
 const matching=referenceWords.filter(w=>descriptionWords.includes(w));
 const invalidFiles=evidence.filter(f=>!['image/jpeg','image/png','image/webp','application/pdf','video/mp4','video/webm'].includes(String(f.mime_type))||f.file_size==null||!Number.isFinite(Number(f.file_size))||Number(f.file_size)<=0||Number(f.file_size)>50*1024*1024);
 return [
  {id:'description',title:'Descripción de la entrega',observation:descriptionWords.length<8,detail:!summary?'No hay una descripción registrada.':descriptionWords.length<8?'La explicación es breve. Comprueba en las evidencias qué se realizó; una descripción breve puede ser correcta.':'Hay una explicación registrada. Su exactitud debe comprobarse manualmente.'},
  {id:'criteria',title:'Referencia a los criterios',observation:!referenceWords.length||!matching.length,detail:!criteria?'No hay criterios guardados para esta entrega. Consulta la tarea con el jefe.':!referenceWords.length?'Los criterios no contienen términos suficientes para comparar. Revisa el resultado manualmente.':matching.length?'Se encontraron términos comunes: '+matching.slice(0,5).join(', ')+'. Esto no confirma el cumplimiento.':'La descripción usa términos diferentes de los criterios. Puede ser otra redacción o un error al escribir; el supervisor debe comprobarlo.'},
  {id:'evidence',title:'Archivos adjuntos',observation:!evidence.length||evidence.length>10||invalidFiles.length>0,detail:!evidence.length?'No se encontraron archivos adjuntos para esta entrega.':invalidFiles.length?'Hay archivos con datos de formato o tamaño incompletos o fuera de los límites. Revisa si puedes abrirlos.':evidence.length>10?'La entrega supera los 10 archivos previstos. Comprueba los adjuntos.':`${evidence.length} ${evidence.length===1?'archivo registrado':'archivos registrados'} con formato y tamaño admitidos. Abre los archivos para comprobar su contenido.`},
  {id:'progress',title:'Porcentaje solicitado',observation:!Number.isFinite(percent)||percent<0||percent>100||!Number.isInteger(percent),detail:Number.isFinite(percent)&&percent>=0&&percent<=100&&Number.isInteger(percent)?`${percent}% solicitado. El supervisor confirma cuánto avance está sustentado por las evidencias.`:'El porcentaje solicitado falta o está fuera del rango de 0 a 100.'}
 ];
}
