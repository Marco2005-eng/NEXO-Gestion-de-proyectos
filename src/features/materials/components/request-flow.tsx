'use client';
import {useState} from 'react';
import type {Row,WorkspaceData} from '@/features/workspace/domain/types';
import {mutateWorkspace} from '@/features/workspace/application/actions';
import {Dialog} from '@/features/workspace/components/dialog';
import {date,label} from '@/features/workspace/components/labels';
import {Icon} from '@/components/shared/icon';
export type RequestFlowMode='deliver'|'receive'|'return'|'usage'|'cancel'|'close';
const titles:Record<RequestFlowMode,string>={
 deliver:'Registrar entrega de materiales',receive:'Confirmar recepción',return:'Registrar devolución',
 usage:'Reportar consumo',cancel:'Cancelar solicitud',close:'Cerrar solicitud',
};
const hints:Record<RequestFlowMode,string>={
 deliver:'Puedes entregar solo una parte de lo reservado. Al guardar se genera un código de 6 dígitos que el solicitante usará para confirmar la recepción.',
 receive:'Confirma la entrega con el código que te compartió el almacén. La solicitud no se marca como recibida hasta confirmar todas las entregas.',
 return:'Solo las devoluciones en buen estado vuelven al stock. Los materiales dañados, perdidos o en mantenimiento quedan registrados sin reponer existencias.',
 usage:'Registra cuánto se usó y cuánto queda de cada material. Si queda material prestable, regístralo como devolución.',
 cancel:'La cancelación conserva el historial, libera las reservas de stock y cierra las aprobaciones pendientes.',
 close:'El cierre finaliza la solicitud después de registrar el consumo o la devolución. Ya no admitirá más movimientos.',
};
const num=(value:unknown)=>Number(value??0);
const quantity=(value:unknown)=>new Intl.NumberFormat('es-PE',{maximumFractionDigits:4}).format(num(value));
type Stats={item:Row;name:string;sku:string;unit:string;approved:number;reserved:number;delivered:number;confirmed:number;returned:number;used:number;pending:number;pendingReturn:number};
export function RequestFlow({mode,request,data,connected,onClose,onSaved}:{mode:RequestFlowMode;request:Row;data:WorkspaceData;connected:boolean;onClose:()=>void;onSaved:(message:string)=>void}){
 const items=data.requestItems.filter(item=>item.request_id===request.id);
 const memberName=(id:unknown)=>{const member=data.members.find(row=>row.id===id);return String(data.profiles.find(profile=>profile.id===member?.user_id)?.display_name??'Solicitante');};
 const projectName=(id:unknown)=>String(data.projects.find(project=>project.id===id)?.name??'Proyecto');
 const stat=(item:Row):Stats=>{
  const balance=data.requestBalances.find(row=>row.request_item_id===item.id);
  const material=data.materials.find(row=>row.id===item.material_id);
  const delivered=num(item.quantity_delivered);
  const returned=balance?num(balance.quantity_returned):data.returnItems.filter(row=>row.request_item_id===item.id).reduce((sum,row)=>sum+num(row.quantity),0);
  const used=balance?num(balance.quantity_used):data.usageReportItems.filter(row=>row.request_item_id===item.id).reduce((sum,row)=>sum+num(row.quantity_used),0);
  const confirmed=balance?num(balance.quantity_confirmed):data.deliveryItems.filter(row=>row.request_item_id===item.id&&data.deliveries.some(delivery=>delivery.id===row.delivery_id&&delivery.confirmed_at)).reduce((sum,row)=>sum+num(row.quantity),0);
  const kind=String(material?.material_kind??balance?.material_kind??'');
  const pendingReturn=kind==='returnable'?Math.max(delivered-returned,0):0;
  return {item,name:String(material?.name??balance?.material_name??'Material'),sku:String(material?.sku??balance?.sku??''),unit:String(material?.unit_of_measure??balance?.unit_of_measure??''),approved:num(item.quantity_approved??item.quantity_requested),reserved:num(item.quantity_reserved),delivered,confirmed,returned,used,pending:Math.max(delivered-returned,0),pendingReturn};
 };
 const stats=items.map(stat);
 const deliverable=stats.filter(row=>row.reserved>0);
 const deliveryWarehouses=Array.from(new Set(deliverable.map(row=>String(row.item.preferred_warehouse_id??'')).filter(Boolean)));
 const deliveryWarehouse=deliveryWarehouses.length===0?'Sin almacén':deliveryWarehouses.length===1?String(data.warehouses.find(warehouse=>warehouse.id===deliveryWarehouses[0])?.name??'Almacén'):'Varios almacenes';
 const returnable=stats.filter(row=>row.pendingReturn>0);
 const consumable=stats.filter(row=>row.pending>0);
 const pendingDeliveries=data.deliveries.filter(delivery=>delivery.request_id===request.id&&!delivery.confirmed_at);
 const usageReport=data.usageReports.find(report=>report.request_id===request.id);
 const [busy,setBusy]=useState(false);const [error,setError]=useState('');
 const [deliveryQuantities,setDeliveryQuantities]=useState<Record<string,string>>(()=>Object.fromEntries(deliverable.map(row=>[String(row.item.id),String(row.reserved)])));
 const [deliveryId,setDeliveryId]=useState(String(pendingDeliveries[0]?.id??''));const [code,setCode]=useState('');
 const [returnQuantities,setReturnQuantities]=useState<Record<string,string>>({});const [conditions,setConditions]=useState<Record<string,string>>({});
 const [usageQuantities,setUsageQuantities]=useState<Record<string,string>>(()=>Object.fromEntries(consumable.map(row=>[String(row.item.id),'0'])));
 const [remainingQuantities,setRemainingQuantities]=useState<Record<string,string>>(()=>Object.fromEntries(consumable.map(row=>[String(row.item.id),String(row.pending)])));
 const [delivered,setDelivered]=useState<{code:string;number:string;status:string}|null>(null);const [copied,setCopied]=useState(false);
 const selectedDelivery=pendingDeliveries.find(delivery=>String(delivery.id)===deliveryId)??pendingDeliveries[0];
 const selectedItems=selectedDelivery?data.deliveryItems.filter(item=>item.delivery_id===selectedDelivery.id):[];
 const deliverNow=(row:Stats)=>Math.min(Math.max(num(deliveryQuantities[String(row.item.id)]),0),row.reserved);
 const deliverySelected=deliverable.filter(row=>deliverNow(row)>0);
 const deliveryIsComplete=deliverable.length>0&&deliverySelected.length>0&&deliverable.every(row=>deliverNow(row)>=row.reserved);
 const deliveryPendingLines=deliverable.filter(row=>deliverNow(row)<row.reserved).length;
 function setDeliveryAll(value:'full'|'clear'){setDeliveryQuantities(Object.fromEntries(deliverable.map(row=>[String(row.item.id),value==='full'?String(row.reserved):''])));}
 function changeUsed(id:string,value:string,pending:number){setUsageQuantities({...usageQuantities,[id]:value});setRemainingQuantities({...remainingQuantities,[id]:String(Math.max(pending-num(value),0))});}
 function changeRemaining(id:string,value:string,pending:number){setRemainingQuantities({...remainingQuantities,[id]:value});setUsageQuantities({...usageQuantities,[id]:String(Math.max(pending-num(value),0))});}
 function previewBlocked(){if(connected)return false;setError('Esta es una vista previa. Inicia sesión para registrar movimientos reales.');return true;}
 async function copyCode(value:string){try{await navigator.clipboard.writeText(value);setCopied(true);}catch{setError('No se pudo copiar el código. Selecciónalo manualmente.');}}
 async function submitDeliver(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');
  const lines=deliverable.map(row=>({request_item_id:String(row.item.id),quantity:num(deliveryQuantities[String(row.item.id)])})).filter(line=>line.quantity>0);
  if(!lines.length){setError('Ingresa al menos una cantidad para entregar.');return;}
  if(lines.some(line=>line.quantity>num(deliverable.find(row=>String(row.item.id)===line.request_item_id)?.reserved))){setError('Una cantidad supera lo reservado para ese material.');return;}
  setBusy(true);
  try{
   const notes=String(new FormData(event.currentTarget).get('notes')??'');
   const result=await mutateWorkspace('request.deliver',{id:request.id,items:lines,notes});
   if(!result.ok){setError(result.message);return;}
   setDelivered({code:String(result.data?.code??''),number:String(result.data?.delivery_number??''),status:String(result.data?.status??'')});
   onSaved(result.message);
  }catch{setError('No se pudo registrar la entrega.');}
  finally{setBusy(false);}
 }
 async function submitReceive(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');if(!selectedDelivery){setError('No hay entregas pendientes de confirmación.');return;}
  if(selectedDelivery.requires_confirmation_code&&!/^\d{6}$/.test(code.trim())){setError('Ingresa el código de 6 dígitos que te compartió el almacén.');return;}
  setBusy(true);
  try{const result=await mutateWorkspace('request.receive',{id:request.id,delivery_id:String(selectedDelivery.id),code:code.trim()||null});if(!result.ok){setError(result.message);return;}onSaved(result.message);onClose();}
  catch{setError('No se pudo confirmar la recepción.');}
  finally{setBusy(false);}
 }
 async function submitReturn(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');
  const lines=returnable.map(row=>({request_item_id:String(row.item.id),quantity:num(returnQuantities[String(row.item.id)]),condition:conditions[String(row.item.id)]??'good'})).filter(line=>line.quantity>0);
  if(!lines.length){setError('Ingresa al menos una cantidad a devolver.');return;}
  if(lines.some(line=>line.quantity>num(returnable.find(row=>String(row.item.id)===line.request_item_id)?.pendingReturn))){setError('Una cantidad supera lo pendiente de devolver.');return;}
  setBusy(true);
  try{const notes=String(new FormData(event.currentTarget).get('notes')??'');const result=await mutateWorkspace('request.return',{id:request.id,items:lines,notes});if(!result.ok){setError(result.message);return;}onSaved(result.message);onClose();}
  catch{setError('No se pudo registrar la devolución.');}
  finally{setBusy(false);}
 }
 async function submitUsage(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');
  const lines=consumable.map(row=>{const used=num(usageQuantities[String(row.item.id)]);const remaining=num(remainingQuantities[String(row.item.id)]);return {request_item_id:String(row.item.id),quantity_used:used,quantity_remaining:remaining,total:used+remaining,pending:row.pending};}).filter(line=>line.total>0);
  if(!lines.length){setError('Registra el consumo o el saldo de al menos un material.');return;}
  if(lines.some(line=>line.total>line.pending)){setError('El consumo más el sobrante supera lo entregado y no devuelto.');return;}
  setBusy(true);
  try{const summary=String(new FormData(event.currentTarget).get('summary')??'');const result=await mutateWorkspace('request.usage',{id:request.id,summary,items:lines.map(({total,pending,...line})=>line)});if(!result.ok){setError(result.message);return;}onSaved(result.message);onClose();}
  catch{setError('No se pudo reportar el consumo.');}
  finally{setBusy(false);}
 }
 async function submitCancel(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');setBusy(true);
  try{const comment=String(new FormData(event.currentTarget).get('comment')??'');const result=await mutateWorkspace('request.cancel',{id:request.id,comment});if(!result.ok){setError(result.message);return;}onSaved(result.message);onClose();}
  catch{setError('No se pudo cancelar la solicitud.');}
  finally{setBusy(false);}
 }
 async function submitClose(event:React.FormEvent<HTMLFormElement>){
  event.preventDefault();if(previewBlocked())return;setError('');setBusy(true);
  try{const result=await mutateWorkspace('request.close',{id:request.id});if(!result.ok){setError(result.message);return;}onSaved(result.message);onClose();}
  catch{setError('No se pudo cerrar la solicitud.');}
  finally{setBusy(false);}
 }
 function footer(cancel='Cancelar',submit='Guardar',disabled=false){return <div className="dialog-footer"><button type="button" className="button secondary" disabled={busy} onClick={onClose}>{cancel}</button>{submit&&<button className="button primary" disabled={busy||disabled}>{busy?'Guardando...':submit}</button>}</div>;}
 return <Dialog title={titles[mode]} wide onClose={()=>{if(!busy)onClose();}}>
  <div className="flow-body">
   {mode!=='deliver'&&<p className="form-help">{hints[mode]}</p>}
   {!connected&&<p className="notice">Esta es una vista previa. Inicia sesión para registrar movimientos reales.</p>}
   {error&&<p className="notice" role="alert">{error}</p>}
   {mode==='deliver'&&(delivered?<div className="delivery-receipt">
    <span className="delivery-receipt-icon"><Icon name="check" size={26}/></span>
    <span className="eyebrow">Entrega registrada</span>
    <h3>{delivered.number||String(request.request_number)}</h3>
    <p>La entrega quedó registrada correctamente. Comparte el código con el solicitante para que confirme la recepción.</p>
    <div className="delivery-code-card">
     <span>Código de confirmación</span>
     <strong>{delivered.code||'------'}</strong>
     <small>Por seguridad, este código no se volverá a mostrar. El solicitante debe ingresarlo desde su sesión.</small>
    </div>
    <div className="delivery-receipt-meta">
     <div><span>Estado</span><span className={'status status-'+delivered.status}><span/>{label(delivered.status)}</span></div>
     <div><span>Solicitud</span><strong>{String(request.request_number)}</strong></div>
     <div><span>Solicitante</span><strong>{memberName(request.requested_by_member_id)}</strong></div>
    </div>
    <div className="delivery-receipt-actions">
     <button type="button" className="button secondary" disabled={!delivered.code} onClick={()=>{void copyCode(delivered.code);}}>{copied?'Código copiado':'Copiar código'}</button>
     <button type="button" className="button primary" onClick={onClose}>Entendido</button>
    </div>
   </div>:<form className="delivery-form" onSubmit={submitDeliver}>
    <section className="delivery-hero">
     <div>
      <span className="eyebrow">Entrega de materiales</span>
      <h3>{String(request.request_number)} · {projectName(request.project_id)}</h3>
      <p>{hints.deliver}</p>
     </div>
     <span className={'status status-'+String(request.status_code)}><span/>{label(request.status_code)}</span>
    </section>
    <div className="delivery-meta">
     <div><span>Solicitante</span><strong>{memberName(request.requested_by_member_id)}</strong></div>
     <div><span>Requerido para</span><strong>{date(request.needed_at)}</strong></div>
     <div><span>Almacén</span><strong>{deliveryWarehouse}</strong></div>
     <div><span>Líneas reservadas</span><strong>{deliverable.length}</strong></div>
    </div>
    {deliveryWarehouses.length>1&&<p className="notice">Esta solicitud usa varios almacenes. El sistema registra una entrega por almacén; ajusta el pedido o divide la entrega.</p>}
    <div className="delivery-toolbar">
     <div>
      <h3>Detalle de la entrega</h3>
      <p>Indica la cantidad real que estás entregando. Puedes dejar saldo pendiente para una entrega posterior.</p>
     </div>
     <div className="delivery-toolbar-actions">
      <button type="button" className="button secondary small" disabled={!deliverable.length} onClick={()=>setDeliveryAll('full')}>Entregar todo</button>
      <button type="button" className="button secondary small" disabled={!deliverable.length} onClick={()=>setDeliveryAll('clear')}>Limpiar</button>
     </div>
    </div>
    {deliverable.length?<div className="table-wrap delivery-table-wrap">
     <table className="delivery-table">
      <thead><tr><th>Material</th><th className="num">Aprobado</th><th className="num">Ya entregado</th><th className="num">Reservado</th><th>Entregar ahora</th></tr></thead>
      <tbody>{deliverable.map(row=>{const amount=deliverNow(row);const remaining=Math.max(row.reserved-amount,0);return <tr key={String(row.item.id)}>
       <td><div className="delivery-material"><strong>{row.name}</strong><small>{[row.sku,row.unit].filter(Boolean).join(' · ')||'Sin código'}</small></div></td>
       <td className="num">{quantity(row.approved)}</td>
       <td className="num">{quantity(row.delivered)}</td>
       <td className="num"><strong>{quantity(row.reserved)}</strong><small className="table-subtitle">pendiente</small></td>
       <td><div className="delivery-quantity"><input aria-label={'Cantidad a entregar de '+row.name} type="number" min="0" max={row.reserved} step="0.0001" inputMode="decimal" value={deliveryQuantities[String(row.item.id)]??''} onChange={event=>setDeliveryQuantities({...deliveryQuantities,[String(row.item.id)]:event.target.value})}/><span>{row.unit||'und'}</span></div>{amount>0&&remaining>0&&<small className="delivery-remaining">Quedan {quantity(remaining)} para otra entrega</small>}</td>
      </tr>;})}</tbody>
     </table>
    </div>:<p className="notice">No hay cantidades reservadas pendientes de entrega.</p>}
    <div className="delivery-note">
     <label htmlFor="delivery-notes">Nota de entrega <span>Opcional</span></label>
     <textarea id="delivery-notes" name="notes" rows={2} maxLength={1000} placeholder="Ej. caja abierta, equipo con rayón o entregado en recepción."/>
     <small>Se mostrará al solicitante en el detalle de la solicitud.</small>
    </div>
    <div className="delivery-footer">
     <div className="delivery-summary">
      <div><span>Líneas a entregar</span><strong>{deliverySelected.length} de {deliverable.length}</strong></div>
      <div><span>Resultado</span><strong className={deliveryIsComplete?'delivery-complete':'delivery-partial'}>{deliverySelected.length?(deliveryIsComplete?'Entrega completa':'Entrega parcial'):'Sin cantidades'}</strong></div>
      {deliverySelected.length>0&&deliveryPendingLines>0&&<div><span>Quedarán pendientes</span><strong>{deliveryPendingLines} {deliveryPendingLines===1?'línea':'líneas'}</strong></div>}
     </div>
     <div className="delivery-footer-actions">
      <button type="button" className="button secondary" disabled={busy} onClick={onClose}>Cancelar</button>
      <button type="submit" className="button primary" disabled={busy||!deliverySelected.length}>{busy?'Guardando...':<>Registrar entrega<Icon name="check" size={16}/></>}</button>
     </div>
    </div>
   </form>)}
   {mode==='receive'&&<form onSubmit={submitReceive}>
    {!pendingDeliveries.length?<p className="notice">No hay entregas pendientes de confirmación.</p>:<>
     <label>Entrega por confirmar<select value={selectedDelivery?String(selectedDelivery.id):''} onChange={event=>{setDeliveryId(event.target.value);setCode('');}}>{pendingDeliveries.map(delivery=><option key={String(delivery.id)} value={String(delivery.id)}>{String(delivery.delivery_number)} · {date(delivery.delivered_at)}</option>)}</select></label>
     {selectedDelivery&&<div className="notice"><strong>{String(selectedDelivery.delivery_number)}</strong><p>Entregada el {date(selectedDelivery.delivered_at)}.</p><ul>{selectedItems.map(item=>{const row=stats.find(value=>String(value.item.id)===String(item.request_item_id));return <li key={String(item.id)}>{row?.name??'Material'}: {quantity(item.quantity)} {row?.unit??''}</li>;})}</ul></div>}
     {selectedDelivery?.requires_confirmation_code?<label>Código de confirmación<input value={code} onChange={event=>setCode(event.target.value.replace(/\D/g,'').slice(0,6))} inputMode="numeric" pattern="[0-9]{6}" maxLength={6} placeholder="6 dígitos" required autoComplete="one-time-code"/><small className="form-help">Pídelo a quien te entregó los materiales. Es obligatorio.</small></label>:<p className="form-help">Esta entrega es anterior al flujo con código. Puedes confirmarla sin código.</p>}
     {footer('Cancelar','Confirmar recepción')}
    </>}
    {!pendingDeliveries.length&&footer('Cerrar','')}
   </form>}
   {mode==='return'&&<form onSubmit={submitReturn}>
    <div className="table-wrap"><table><thead><tr><th>Material</th><th>Entregado</th><th>Devuelto</th><th>Pendiente</th><th>Devolver</th><th>Condición</th></tr></thead><tbody>{returnable.map(row=><tr key={String(row.item.id)}><td>{row.name}<small className="table-subtitle">{row.sku}</small></td><td>{quantity(row.delivered)} {row.unit}</td><td>{quantity(row.returned)}</td><td>{quantity(row.pendingReturn)}</td><td><input aria-label={'Cantidad a devolver de '+row.name} type="number" min="0" max={row.pendingReturn} step="0.0001" value={returnQuantities[String(row.item.id)]??''} onChange={event=>setReturnQuantities({...returnQuantities,[String(row.item.id)]:event.target.value})}/></td><td><select aria-label={'Condición de '+row.name} value={conditions[String(row.item.id)]??'good'} onChange={event=>setConditions({...conditions,[String(row.item.id)]:event.target.value})}><option value="good">Buen estado (vuelve a stock)</option><option value="damaged">Dañado</option><option value="lost">Perdido</option><option value="maintenance_required">Requiere mantenimiento</option></select></td></tr>)}</tbody></table></div>
    {!returnable.length&&<p className="notice">No hay materiales prestables pendientes de devolución.</p>}
    <label>Nota de devolución<textarea name="notes" rows={2} maxLength={1000} placeholder="Observaciones (opcional)"/></label>
    {footer('Cancelar','Registrar devolución',!returnable.length)}
   </form>}
   {mode==='usage'&&(usageReport?<>
    <div className="notice"><strong>Consumo reportado</strong><p>{String(usageReport.summary)}</p><small className="muted">{date(usageReport.reported_at)}</small></div>
    <div className="table-wrap"><table><thead><tr><th>Material</th><th>Usado</th><th>Sobrante</th></tr></thead><tbody>{data.usageReportItems.filter(item=>item.usage_report_id===usageReport.id).map(item=>{const row=stats.find(value=>String(value.item.id)===String(item.request_item_id));return <tr key={String(item.id)}><td>{row?.name??'Material'}</td><td>{quantity(item.quantity_used)}</td><td>{quantity(item.quantity_remaining)}</td></tr>;})}</tbody></table></div>
    {footer('Cerrar','')}
   </>:<form onSubmit={submitUsage}>
    <div className="table-wrap"><table><thead><tr><th>Material</th><th>Entregado</th><th>Ya devuelto</th><th>Disponible</th><th>Usado</th><th>Sobrante</th></tr></thead><tbody>{consumable.map(row=><tr key={String(row.item.id)}><td>{row.name}<small className="table-subtitle">{row.sku}</small></td><td>{quantity(row.delivered)} {row.unit}</td><td>{quantity(row.returned)}</td><td>{quantity(row.pending)}</td><td><input aria-label={'Cantidad usada de '+row.name} type="number" min="0" max={row.pending} step="0.0001" value={usageQuantities[String(row.item.id)]??'0'} onChange={event=>changeUsed(String(row.item.id),event.target.value,row.pending)}/></td><td><input aria-label={'Cantidad sobrante de '+row.name} type="number" min="0" max={row.pending} step="0.0001" value={remainingQuantities[String(row.item.id)]??'0'} onChange={event=>changeRemaining(String(row.item.id),event.target.value,row.pending)}/></td></tr>)}</tbody></table></div>
    {!consumable.length&&<p className="notice">No hay materiales disponibles para reportar consumo.</p>}
    <label>Resumen del consumo<textarea name="summary" rows={3} minLength={5} maxLength={2000} required placeholder="¿En qué se usaron los materiales?"/></label>
    {footer('Cancelar','Reportar consumo',!consumable.length)}
   </form>)}
   {mode==='cancel'&&<form onSubmit={submitCancel}>
    <p>Estado actual: <span className={'status status-'+request.status_code}>{label(request.status_code)}</span></p>
    <label>Motivo de la cancelación<textarea name="comment" rows={4} minLength={3} maxLength={1000} required placeholder="Explica por qué se cancela la solicitud"/></label>
    {footer('Volver','Cancelar solicitud')}
   </form>}
   {mode==='close'&&<form onSubmit={submitClose}>
    <div className="notice"><strong>{String(request.request_number)}</strong><p>La solicitud quedará cerrada y no admitirá nuevas entregas, devoluciones ni reportes de consumo.</p></div>
    {footer('Volver','Cerrar solicitud')}
   </form>}
  </div>
 </Dialog>;
}
