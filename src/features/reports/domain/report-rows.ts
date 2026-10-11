import type {Row} from '@/features/workspace/domain/types';
export type ReportKind='investment'|'movements'|'costs'|'tasks'|'inventory'|'requests';
export type ReportRow={id:string;projectId:string;day:string;cells:Record<string,string|number>;amount?:number};
export const reportDay=(value:unknown)=>{if(!value)return '';const text=String(value);return text.length===10?text:new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(text));};
export function buildReport(kind:ReportKind,data:Record<string,Row[]>):ReportRow[]{
 const list=(key:string)=>data[key]??[];
 const name=(key:string,id:unknown)=>String(list(key).find(r=>r.id===id)?.name??'Sin asignar');
 const project=(id:unknown)=>name('projects',id);
 const unit=(id:unknown)=>String(list('materials').find(m=>m.id===id)?.unit_of_measure??'');
 if(kind==='investment')return list('investment').map(c=>{const movement=list('movements').find(m=>m.id===c.movement_id);return {id:String(c.id),projectId:String(c.project_id),day:reportDay(c.recorded_at),amount:c.amount===null?undefined:Number(c.amount),cells:{Fecha:reportDay(c.recorded_at),Proyecto:project(c.project_id),Material:name('materials',movement?.material_id),Tipo:movement?.movement_type_code==='initial'?'Inversión inicial':'Compra',Cantidad:Number(c.quantity),Unidad:unit(movement?.material_id),'Precio histórico (S/)':c.unit_cost===null?'Pendiente de valorizar':Number(c.unit_cost),'Inversión (S/)':c.amount===null?'Pendiente de valorizar':Number(c.amount)}};});
 if(kind==='movements')return list('movements').map(m=>({id:String(m.id),projectId:String(m.project_id??''),day:reportDay(m.occurred_at),cells:{Fecha:reportDay(m.occurred_at),Proyecto:project(m.project_id),Material:name('materials',m.material_id),Unidad:unit(m.material_id),Almacén:name('warehouses',m.warehouse_id),Movimiento:Number(m.quantity_delta)>0?'Entrada':Number(m.quantity_delta)<0?'Salida':Number(m.reserved_delta)>0?'Reserva':'Liberación',Tipo:String(m.movement_type_code),Cantidad:Math.abs(Number(m.quantity_delta))||Math.abs(Number(m.reserved_delta)),Motivo:String(m.reason??'—')}}));
 if(kind==='costs')return list('movements').filter(m=>m.movement_type_code==='delivery').map(m=>{
  const request=list('requests').find(r=>r.id===m.request_id);
  const item=list('items').find(i=>i.request_id===m.request_id&&i.material_id===m.material_id&&i.preferred_warehouse_id===m.warehouse_id);
  const price=item?.unit_cost;const amount=price===null||price===undefined?undefined:Number(m.quantity)*Number(price);
  return {id:String(m.id),projectId:String(m.project_id??''),day:reportDay(m.occurred_at),amount,cells:{Solicitud:String(request?.request_number??'—'),Proyecto:project(m.project_id),Material:name('materials',m.material_id),Unidad:unit(m.material_id),'Cantidad entregada':Number(m.quantity),'Costo unitario (S/)':price===null||price===undefined?'Sin costo':Number(price),'Costo entregado (S/)':amount??'Sin costo',Fecha:reportDay(m.occurred_at)}};
 });
 if(kind==='tasks')return list('tasks').map(t=>({id:String(t.id),projectId:String(t.project_id),day:reportDay(t.due_at),cells:{Tarea:String(t.title),Proyecto:project(t.project_id),Estado:String(t.status_code),Prioridad:String(t.priority_code),'Avance validado (%)':Number(t.progress),'Fecha límite':reportDay(t.due_at)||'Sin fecha',Situación:t.status_code==='completed'?'Completada':t.status_code==='cancelled'?'Cancelada':t.due_at&&new Date(String(t.due_at)).getTime()<Date.now()?'Vencida':'Dentro del plazo'}}));
 if(kind==='inventory')return list('inventory').map(i=>({id:String(i.material_id)+':'+i.warehouse_id,projectId:String(i.warehouse_project_id??''),day:'',amount:Number(i.on_hand)*Number(i.unit_cost??0),cells:{Material:String(i.name),Unidad:String(i.unit_of_measure),Proyecto:project(i.warehouse_project_id),Almacén:String(i.warehouse_name),'Stock físico':Number(i.on_hand),Reservado:Number(i.reserved),Disponible:Number(i.available),'Valor actual (S/)':Number(i.on_hand)*Number(i.unit_cost??0),Estado:String(i.availability_status)}}));
 return list('requests').map(r=>({id:String(r.id),projectId:String(r.project_id),day:reportDay(r.created_at),amount:Number(r.estimated_total),cells:{Solicitud:String(r.request_number),Proyecto:project(r.project_id),Fecha:reportDay(r.created_at),Estado:String(r.status_code),'Monto solicitado (S/)':Number(r.estimated_total),Justificación:String(r.justification??'—')}}));
}
export function reportCsv(rows:ReportRow[]){
 if(!rows.length)return '';const keys=Object.keys(rows[0].cells);
 const escape=(v:unknown)=>'"'+String(v??'').replace(/^[=+@\-\t\r]/,"'$&").replace(/"/g,'""')+'"';
 return '\uFEFF'+[keys.map(escape).join(','),...rows.map(r=>keys.map(k=>escape(r.cells[k])).join(','))].join('\r\n');
}
