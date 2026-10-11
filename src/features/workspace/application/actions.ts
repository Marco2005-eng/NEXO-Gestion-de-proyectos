'use server';
import { revalidatePath } from 'next/cache';
import { requireUser } from '@/features/auth/application/session';
import { loadWorkspace } from '../infrastructure/load-workspace';
import { hasGrant } from '../domain/types';
import {taskDueAt,saveError} from '../domain/task-edit';
export type MutationResult = { ok: boolean; message: string };
function text(payload: Record<string, unknown>, key: string, required = false) {
  const value = String(payload[key] ?? '').trim();
  if (required && !value) throw new Error('Completa los campos obligatorios.');
  if (value.length > 5000) throw new Error('El texto excede el tamaño permitido.');
  return value;
}
function numeric(payload: Record<string, unknown>, key: string, max = 1e9) {
  const value = Number(payload[key]);
  if (!Number.isFinite(value) || value < 0 || value > max) throw new Error('Revisa las cantidades ingresadas.');
  return value;
}
export async function mutateWorkspace(kind: string, payload: Record<string, unknown>): Promise<MutationResult> {
  try {
    const { client, user } = await requireUser();
    if(kind==='material.entry'||kind.startsWith('budget.')) {
      const {error}=kind==='material.entry'?await client.rpc('nexo_material_entry',{p_payload:payload}):await client.rpc('nexo_budget_command',{p_command:kind,p_payload:payload});
      if(error)return {ok:false,message:['PGRST202','42883'].includes(error.code)?'Ejecuta supabase/21_inversion_materiales_presupuesto.sql para habilitar inversión y presupuesto.':error.message};
      revalidatePath('/','layout');return {ok:true,message:'Operación guardada. Balance actualizado.'};
    }
    if(kind==='material.import') {
      const {error}=await client.rpc('nexo_import_materials',{p_payload:payload});
      if(error)return {ok:false,message:['PGRST202','42883'].includes(error.code)?'Ejecuta supabase/15_materiales_excel_solicitudes.sql antes de importar.':error.message};
      revalidatePath('/','layout');return {ok:true,message:'Materiales importados. Existencias y precios actualizados.'};
    }
    if (['request.update','request.receive','request.create','request.submit','request.decide','request.reserve','request.deliver'].includes(kind)) {
      const { error } = await client.rpc('nexo_material_command', { p_command: kind, p_payload: payload });
      if (error) {
        if (error.code === 'PGRST202' || error.code === '42883') return { ok: false, message: 'Para habilitar este flujo ejecuta supabase/05_flujos_interfaces.sql en SQL Editor.' };
        return { ok: false, message: error.message };
      }
      revalidatePath('/', 'layout');
      return { ok: true, message: 'Operación registrada correctamente.' };
    }
    const data = await loadWorkspace();
    const organizationId = text(payload, 'organization_id', true);
    const project = data.projects.find(p => p.id === payload.project_id);
    const currentProject = data.projects.find(p => p.id === payload.id);
    const currentTask = data.tasks.find(t => t.id === payload.id);
    const taskProject = data.projects.find(p => p.id === currentTask?.project_id);
    let code = ''; let scopeProject: string | null = null; let scopeArea: string | null = null;
    if (kind === 'project.save') { code = payload.id ? 'project.manage' : 'project.create'; scopeProject = currentProject ? String(currentProject.id) : null; scopeArea = (currentProject?.area_id ?? payload.area_id ?? null) as string | null; }
    else if (kind === 'task.save') { code = payload.id ? 'task.manage' : 'task.create'; scopeProject = String((payload.id ? taskProject : project)?.id ?? ''); scopeArea = ((payload.id ? (currentTask?.area_id ?? taskProject?.area_id) : project?.area_id) ?? null) as string | null; }
    else if (kind === 'material.create') code = 'material.manage_catalog';
    else if (kind === 'area.create') code = 'area.manage';
    else if (kind === 'diagram.save') { code = 'diagram.manage'; scopeProject = String(project?.id ?? ''); scopeArea = project?.area_id as string | null; }
    else throw new Error('Operación no disponible.');
    if (!hasGrant(data.grants, code, organizationId, scopeProject, scopeArea)) throw new Error('No tienes permiso para esta operación en el alcance seleccionado.');
    if (payload.id && kind === 'project.save' && currentProject?.organization_id !== organizationId) throw new Error('Proyecto inválido.');
    if (kind === 'task.save' && (payload.id ? taskProject : project)?.organization_id !== organizationId) throw new Error('Proyecto inválido.');
    if (payload.area_id && !data.areas.some(a => a.id === payload.area_id && a.organization_id === organizationId)) throw new Error('Área inválida.');
    let error: { message: string; code?: string } | null = null;
    if (kind === 'project.save') {
      const status = text(payload,'status_code',true);
      if (!['draft','planning','active','on_hold','completed','cancelled'].includes(status)) throw new Error('Estado inválido.');
      const values = { code: text(payload,'code',true), name: text(payload,'name',true), description: text(payload,'description'), status_code: status, planned_start_date: text(payload,'planned_start_date') || null, planned_end_date: text(payload,'planned_end_date') || null, budget: numeric(payload,'budget'), area_id: text(payload,'area_id') || null };
      const response = payload.id ? await client.from('projects').update(values).eq('id',payload.id).select('id').single() : await client.from('projects').insert({ ...values, organization_id: organizationId, created_by: user.id }).select('id').single();
      error = response.error;
    } else if (kind === 'task.save') {
      const status = text(payload,'status_code',true); const priority = text(payload,'priority_code',true);
      if (!['pending','in_progress','in_review','needs_changes','blocked','completed','cancelled'].includes(status) || !['low','medium','high','critical'].includes(priority)) throw new Error('Estado o prioridad inválidos.');
      const dueAt=taskDueAt(text(payload,'due_at'),currentTask?.due_at);
      if(dueAt&&currentTask?.planned_start_at&&Date.parse(dueAt)<Date.parse(String(currentTask.planned_start_at)))throw new Error('La fecha de entrega no puede ser anterior al inicio previsto de la tarea.');
      const assigned=data.assignees.filter(a=>a.task_id===currentTask?.id);
      const {error:rpcError}=await client.rpc('nexo_save_assigned_task',{p_payload:{
        id:payload.id??null,project_id:currentTask?.project_id??project?.id,title:text(payload,'title',true),description:text(payload,'description'),status_code:status,priority_code:priority,due_at:dueAt,
        responsible_member_id:payload.responsible_member_id??assigned.find(a=>a.assignment_type==='responsible')?.member_id??'',
        reviewer_member_id:payload.reviewer_member_id??assigned.find(a=>a.assignment_type==='reviewer')?.member_id??''
      }});
      if(rpcError&&['PGRST202','42883'].includes(rpcError.code))return {ok:false,message:'Ejecuta supabase/16_crear_tarea_con_responsable.sql para guardar la tarea y su responsable.'};
      error=rpcError;
    } else if (kind === 'area.create') {
      ({ error } = await client.from('areas').insert({organization_id: organizationId, code: text(payload,'code',true), name: text(payload,'name',true), description: text(payload,'description'), created_by: user.id}).select('id').single());
    } else if (kind === 'material.create') {
      const materialKind = text(payload,'material_kind',true);
      if (!['consumable','returnable','service','license'].includes(materialKind)) throw new Error('Tipo inválido.');
      ({ error } = await client.from('materials').insert({organization_id: organizationId, sku: text(payload,'sku',true), name: text(payload,'name',true), unit_of_measure: text(payload,'unit_of_measure',true), material_kind: materialKind, minimum_stock: numeric(payload,'minimum_stock'), standard_cost: numeric(payload,'standard_cost'), requires_return: materialKind === 'returnable', requires_usage_report: materialKind === 'consumable', created_by: user.id}).select('id').single());
    } else if (kind === 'diagram.save') {
      if (project?.organization_id !== organizationId) throw new Error('Proyecto inválido.');
      const values = { name: text(payload,'name',true), source: text(payload,'source',true) };
      if (payload.id && !data.diagrams.some(d => d.id === payload.id && d.project_id === project.id)) throw new Error('Diagrama inválido.');
      const response = payload.id ? await client.from('activity_diagrams').update(values).eq('id',payload.id).select('id').single() : await client.from('activity_diagrams').insert({...values,project_id:project.id,created_by:user.id}).select('id').single();
      error = response.error;
    }
    if (error) return { ok: false, message: saveError(error) };
    revalidatePath('/', 'layout');
    return { ok: true, message: 'Cambios guardados en Supabase.' };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : 'No se pudo completar la operación.' };
  }
}
