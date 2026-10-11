'use server';
import {requireUser} from '@/features/auth/application/session';
import {loadWorkspace} from '@/features/workspace/infrastructure/load-workspace';
import {hasGrant,type Row} from '@/features/workspace/domain/types';

export async function loadReport(organizationId:string) {
 const {client}=await requireUser();const workspace=await loadWorkspace();
 const projects=workspace.projects.filter(p=>p.organization_id===organizationId&&hasGrant(workspace.grants,'report.view',organizationId,String(p.id),p.area_id as string|null));
 if(!hasGrant(workspace.grants,'report.view',organizationId)&&!workspace.grants.some(g=>g.organizationId===organizationId&&g.codes.includes('report.view')))throw new Error('No tienes permiso para consultar estos reportes.');
 const definitions={projects:'projects',investment:'project_material_costs',movements:'stock_movements',materials:'materials',inventory:'inventory_availability',requests:'material_requests',tasks:'tasks',items:'material_request_items',warehouses:'warehouses'};
 const result:Record<string,Row[]>={};
 // Consulta todas las páginas con RLS; no produce totales sobre solo los primeros 500 registros.
 for(const [key,table] of Object.entries(definitions)){
  const all:Row[]=[];let offset=0;
  while(true){
   let query=client.from(table).select('*').order(table==='inventory_availability'?'material_id':'id');
   if(table==='inventory_availability')query=query.order('warehouse_id');
   if(['tasks','material_request_items'].includes(table)){
    const ids=key==='tasks'?result.projects.map(p=>p.id):result.requests.map(r=>r.id);
    if(!ids.length)break;
    query=query.in(key==='tasks'?'project_id':'request_id',ids);
   }else query=query.eq('organization_id',organizationId);
   if(['projects','tasks','materials','material_requests'].includes(table))query=query.is('deleted_at',null);
   const {data,error}=await query.range(offset,offset+499);
   if(error&&key==='investment')throw new Error('Ejecuta supabase/21_inversion_materiales_presupuesto.sql para habilitar el balance de inversión.');
   if(error)throw new Error('No se pudo cargar el reporte completo. Revisa tus permisos y vuelve a intentar.');
   all.push(...(data??[]) as Row[]);if(!data||data.length<500)break;offset+=500;
  }
  const allowed=new Set((result.projects??projects).map(p=>p.id));
  result[key]=key==='projects'?all.filter(p=>hasGrant(workspace.grants,'report.view',organizationId,String(p.id),p.area_id as string|null)):['investment','movements','requests','inventory'].includes(key)?all.filter(r=>(r.project_id??r.warehouse_project_id)?allowed.has(r.project_id??r.warehouse_project_id):hasGrant(workspace.grants,'report.view',organizationId)):all;
 }
 return result;
}
