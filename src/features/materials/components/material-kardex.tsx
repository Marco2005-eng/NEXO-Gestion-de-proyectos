'use client';
import {useEffect,useState} from 'react';
import {Dialog} from '@/features/workspace/components/dialog';
import {date,label} from '@/features/workspace/components/labels';
import {loadMaterialKardex,type KardexRow} from '../kardex-actions';
type Result={total:number;limit:number;offset:number;rows:KardexRow[]};
function quantity(value:unknown){return new Intl.NumberFormat('es-PE',{maximumFractionDigits:4}).format(Number(value??0));}
function time(value:unknown){if(!value)return 'Sin fecha';const d=new Date(String(value));return Number.isNaN(d.getTime())?'Sin fecha':d.toLocaleString('es-PE',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',timeZone:'America/Lima'});}
export function MaterialKardex({projectId,materialId,title,connected,onClose}:{projectId:string;materialId?:string|null;title:string;connected:boolean;onClose:()=>void}){
 const [result,setResult]=useState<Result|null>(null);const [loading,setLoading]=useState(true);const [error,setError]=useState('');
 useEffect(()=>{let active=true;setLoading(true);setError('');if(!connected){setError('Esta es una vista previa. Inicia sesión para consultar el kardex real.');setLoading(false);return;}if(!projectId){setError('Selecciona un proyecto para consultar el kardex.');setLoading(false);return;}loadMaterialKardex(projectId,materialId).then(value=>{if(active)setResult(value);}).catch(e=>{if(active)setError(e instanceof Error?e.message:'No se pudo consultar el kardex.');}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[projectId,materialId,connected]);
 return <Dialog title={'Kardex de '+title} wide onClose={onClose}>
  <div style={{padding:24}}>
   {loading&&<p role="status">Consultando movimientos...</p>}
   {error&&<p className="notice" role="alert">{error}</p>}
   {!loading&&!error&&result&&<>
    <p className="form-help">Movimientos del proyecto, del más reciente al más antiguo. El saldo y la reserva son los acumulados después de cada movimiento.</p>
    <div className="table-wrap"><table>
     <thead><tr><th>Fecha</th><th>Movimiento</th><th>Material</th><th>Almacén</th><th>Cantidad</th><th>Saldo</th><th>Reserva</th><th>Referencia</th><th>Registrado por</th></tr></thead>
     <tbody>{result.rows.map(row=><tr key={row.id}>
      <td>{time(row.occurred_at)}</td>
      <td><span className={'status status-'+row.movement_type_code}>{row.movement_type_name||label(row.movement_type_code)}</span></td>
      <td>{row.material_name}<small className="table-subtitle">{row.sku}</small></td>
      <td>{row.warehouse_name}</td>
      <td>{quantity(row.quantity)} {row.unit_of_measure}<small className="table-subtitle">{Number(row.quantity_delta)>=0?'+':''}{quantity(row.quantity_delta)}</small></td>
      <td>{quantity(row.balance_after)}</td>
      <td>{quantity(row.reserved_balance_after)}<small className="table-subtitle">{Number(row.reserved_delta)>=0?'+':''}{quantity(row.reserved_delta)}</small></td>
      <td>{row.request_number?<><span>{row.request_number}</span><small className="table-subtitle">{date(row.occurred_at)}</small></>:row.reason??label(row.reference_type)}</td>
      <td>{row.recorded_by_name}</td>
     </tr>)}</tbody>
    </table></div>
    {result.rows.length===0?<p className="form-help">Todavía no hay movimientos para este filtro.</p>:<p className="form-help">Mostrando {result.rows.length} de {result.total} movimientos.</p>}
   </>}
  </div>
  <div className="dialog-footer"><button type="button" className="button secondary" onClick={onClose}>Cerrar</button></div>
 </Dialog>;
}
