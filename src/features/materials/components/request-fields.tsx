'use client';
import {useState} from 'react';
import type {Row,WorkspaceData} from '@/features/workspace/domain/types';
import {money} from '@/features/workspace/components/labels';
import {Icon} from '@/components/shared/icon';
export type RequestLine={material_id:string;warehouse_id:string;quantity:string};
export function RequestFields({data,organizationId,projectId,row,items,onItems}:{data:WorkspaceData;organizationId:string;projectId:string;row?:Row;items:RequestLine[];onItems:(items:RequestLine[])=>void}){
 const warehouses=data.warehouses.filter(w=>w.organization_id===organizationId&&w.is_active!==false&&(!w.project_id||w.project_id===projectId));
 const [warehouse,setWarehouse]=useState(items[0]?.warehouse_id??'');
 const ownMembers=new Set(data.members.filter(m=>m.user_id===data.userId&&m.status==='active').map(m=>m.id));
 const tasks=data.tasks.filter(t=>t.project_id===projectId&&(data.assignees.some(a=>a.task_id===t.id&&ownMembers.has(a.member_id)&&['responsible','collaborator'].includes(String(a.assignment_type)))||data.projectMembers.some(m=>m.project_id===projectId&&ownMembers.has(m.member_id)&&m.is_project_manager&&!m.left_at)||data.platformAdmin||data.grants.some(g=>g.organizationId===organizationId&&g.scope==='organization'&&g.codes.includes('task.manage'))));
 const stock=(id:string)=>data.inventory.find(i=>i.material_id===id&&i.warehouse_id===warehouse);
 const cost=(id:string)=>Number(stock(id)?.unit_cost??data.materials.find(m=>m.id===id)?.standard_cost??0);
 return <>
  <section className="request-section full" aria-labelledby="request-destination-title">
   <div className="request-section-heading"><span className="request-step">02</span><div><h3 id="request-destination-title">Destino de los materiales</h3><p>Relaciona el pedido con el trabajo que vas a realizar.</p></div></div>
   <div className="request-context-grid"><label>Tarea asociada <span className="request-optional">Opcional</span><select name="task_id" defaultValue={String(row?.task_id??'')}><option value="">Pedido general del proyecto</option>{tasks.map(t=><option key={String(t.id)} value={String(t.id)}>{t.title}</option>)}</select></label><label>Almacén de salida <span className="required">*</span><select value={warehouse} required onChange={e=>{setWarehouse(e.target.value);onItems(items.map(i=>({...i,warehouse_id:e.target.value,material_id:''})));}}><option value="">Seleccionar almacén</option>{warehouses.map(w=><option key={String(w.id)} value={String(w.id)}>{w.name}</option>)}</select></label></div>
  </section>
  <section className="request-section full" aria-labelledby="request-materials-title">
   <div className="request-section-heading request-materials-heading"><span className="request-step">03</span><div><h3 id="request-materials-title">Materiales del pedido</h3><p>{items.length} {items.length===1?'material':'materiales'} · cantidades y costos estimados</p></div><button type="button" className="button secondary small" disabled={!warehouse||items.length>=30} onClick={()=>onItems([...items,{material_id:'',warehouse_id:warehouse,quantity:'1'}])}><Icon name="plus" size={16}/>Agregar material</button></div>
   {!warehouse&&<p className="request-stock-hint">Selecciona el almacén para ver los materiales disponibles.</p>}
   <div className="request-item-list">{items.map((item,index)=>{
    const inventory=stock(item.material_id);const unit=String(inventory?.unit_of_measure??'unidad');
    return <article className="request-item" key={index}>
     <div className="request-item-heading"><span>Material {String(index+1).padStart(2,'0')}</span>{items.length>1&&<button type="button" className="icon-button" aria-label={'Quitar material '+(index+1)} title="Quitar material" onClick={()=>onItems(items.filter((_,i)=>i!==index))}><Icon name="close" size={16}/></button>}</div>
     <div className="request-item-grid"><label>Material <span className="required">*</span><select required disabled={!warehouse} value={item.material_id} onChange={e=>onItems(items.map((r,i)=>i===index?{...r,material_id:e.target.value,warehouse_id:warehouse}:r))}><option value="">Seleccionar material</option>{data.inventory.filter(i=>i.organization_id===organizationId&&i.warehouse_id===warehouse&&(!items.some((r,n)=>n!==index&&r.material_id===i.material_id))).map(i=><option key={String(i.material_id)} value={String(i.material_id)}>{i.name} · {i.unit_of_measure}</option>)}</select></label><label>Cantidad <span className="required">*</span><input type="number" min="0.0001" max="1000000" step="0.0001" required value={item.quantity} onChange={e=>onItems(items.map((r,i)=>i===index?{...r,quantity:e.target.value}:r))}/></label><div className="request-item-subtotal"><span>Subtotal</span><strong>{money(Number(item.quantity)*cost(item.material_id))}</strong></div></div>
     {item.material_id&&<div className="request-item-meta"><span>Disponible: <strong>{inventory?.available??0} {unit}</strong></span><span>Precio unitario: <strong>{money(cost(item.material_id))}</strong></span></div>}
     {Number(item.quantity)>Number(inventory?.available??Infinity)&&<p className="request-stock-warning" role="status">La cantidad supera el stock disponible. Se necesita un nuevo ingreso antes de reservar.</p>}
    </article>;
   })}</div>
   <div className="request-total"><div><span>Total estimado</span><small>{items.filter(i=>i.material_id).length} {items.filter(i=>i.material_id).length===1?'material seleccionado':'materiales seleccionados'}</small></div><strong aria-live="polite">{money(items.reduce((n,r)=>n+Number(r.quantity)*cost(r.material_id),0))}</strong></div>
   <p className="request-save-hint">Guarda tu borrador y envíalo a aprobación desde el detalle del pedido.</p>
  </section>
 </>;
}
