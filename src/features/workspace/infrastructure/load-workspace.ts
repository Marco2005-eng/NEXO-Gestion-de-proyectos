import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import { getSupabaseConfig } from '@/lib/supabase/config';
import type { WorkspaceData, Row, Grant } from '../domain/types';
export async function loadWorkspace(): Promise<WorkspaceData> {
  const empty: WorkspaceData = { connected: false, userId: '', userName: 'Visitante', grants: [], organizations: [], projects: [], tasks: [], materials: [], inventory: [], requests: [], requestItems: [], history: [], approvals: [], documents: [], diagrams: [], areas: [], warehouses: [], members: [], profiles: [], assignees: [], summaries: [], roles: [], notifications: [], errors: [], projectMembers: [], registeredUsers: [], registrationEnabled: Boolean(process.env.SUPABASE_SECRET_KEY) };
  if (!getSupabaseConfig()) return empty;
  const { client, user } = await requireUser();
  const platform=await client.rpc('nexo_is_platform_admin');
  const queries = {
    organizations: ['organizations', 'id,name,currency_code'],
    projects: ['projects', 'id,organization_id,area_id,code,name,description,status_code,priority_code,planned_start_date,planned_end_date,budget,created_by'],
    tasks: ['tasks', 'id,project_id,area_id,title,description,status_code,priority_code,progress,planned_start_at,due_at,completed_at,created_by,acceptance_criteria,evidence_required'],
    taskSubmissions: ['task_submissions', '*'],
    taskEvidence: ['task_evidence', '*'],
    materials: ['materials', 'id,organization_id,sku,name,unit_of_measure,material_kind,minimum_stock,standard_cost'],
    inventory: ['inventory_availability', '*'],
    requests: ['material_requests', '*'],
    requestItems: ['material_request_items', 'id,request_id,material_id,preferred_warehouse_id,quantity_requested,quantity_approved,quantity_reserved,quantity_delivered,unit_cost'],
    history: ['material_request_status_history', '*'],
    approvals: ['approval_instances', 'id,organization_id,subject_id,subject_type,project_id,status_code,requested_by_member_id,created_at'],
    documents: ['documents', 'id,organization_id,project_id,file_id,title,document_type,version,created_at'],
    diagrams: ['activity_diagrams', 'id,project_id,name,source,format,version,created_at'],
    areas: ['areas', 'id,organization_id,code,name,description'],
    warehouses: ['warehouses', '*'],
    members: ['organization_members', 'id,organization_id,user_id,status,job_title'],
    profiles: ['profiles', 'id,display_name'],
    assignees: ['task_assignees', 'task_id,member_id,assignment_type'],
    projectMembers: ['project_members', 'id,project_id,member_id,project_title,is_project_manager,left_at'],
    summaries: ['project_progress_summary', '*'],
    roles: ['roles', 'id,organization_id,code,name,description,is_system,is_active'],
    notifications: ['notifications', '*'],
  } as const;
  const result = { ...empty, connected: true, platformAdmin:!!platform.data, userId: user.id, userName: user.email?.split('@')[0] ?? 'Usuario' };
  await Promise.all(Object.entries(queries).map(async ([key, [table, columns]]) => {
    let query = client.from(table).select(columns).limit(500);
    if (table==='notifications') query=query.order('created_at',{ascending:false}).limit(100);
    if (['projects','tasks','materials','material_requests','documents','activity_diagrams','areas'].includes(table)) query = query.is('deleted_at', null);
    const completeInventory=['materials','inventory_availability','warehouses'].includes(table);
    if(completeInventory)query=table==='inventory_availability'?query.order('material_id').order('warehouse_id'):query.order('id');
    const response = await query;let data:unknown=response.data;let error=response.error;
    if(completeInventory&&!error){const all=[...(response.data??[])];let offset=all.length;while(offset>0&&offset%500===0){const page=await query.range(offset,offset+499);if(page.error){error=page.error;break;}all.push(...(page.data??[]));if(!page.data?.length||page.data.length<500)break;offset+=page.data.length;}data=all;}
    if(table==='tasks'&&error?.code==='42703'){const fallback=await client.from('tasks').select(columns.replace(',evidence_required','')).is('deleted_at',null).limit(500);data=fallback.data;error=fallback.error;}
    if (error) result.errors.push(key);
    else (result as unknown as Record<string, unknown>)[key] = data as unknown as Row[];
  }));
  const reviewers=await client.rpc('nexo_task_reviewers');
  result.taskReviewers=reviewers.data??[];
  const profile = result.profiles.find(p => p.id === user.id);
  if (profile?.display_name) result.userName = String(profile.display_name);
  const [assignments, rolePermissions, permissions] = await Promise.all([
    client.from('member_role_assignments').select('*'),
    client.from('role_permissions').select('role_id,permission_id'),
    client.from('permissions').select('id,code,name,module,description'),
  ]);
  if (assignments.error || rolePermissions.error || permissions.error) result.errors.push('permissions');
  result.permissions=permissions.data??[];
  result.rolePermissions=rolePermissions.data??[];
  result.roleAssignments=assignments.data??[];
  const now = Date.now();
  result.grants = (assignments.data ?? []).filter(a => {
    const member = result.members.find(m => m.id === a.member_id && m.user_id === user.id && m.status === 'active');
    return member && member.organization_id === a.organization_id && new Date(a.valid_from).getTime() <= now && (!a.valid_until || new Date(a.valid_until).getTime() > now) && result.roles.some(r => r.id === a.role_id && r.is_active);
  }).map(a => ({ organizationId: a.organization_id, scope: a.scope_type, projectId: a.project_id, areaId: a.area_id,
    codes: (rolePermissions.data ?? []).filter(rp => rp.role_id === a.role_id).map(rp => permissions.data?.find(p => p.id === rp.permission_id)?.code).filter((c): c is string => !!c),
  } satisfies Grant));
  if(result.platformAdmin)result.grants=result.organizations.map(o=>({organizationId:String(o.id),scope:'organization',projectId:null,areaId:null,codes:(permissions.data??[]).map(p=>p.code)}));
  await Promise.all(result.organizations.map(async organization => {
    const {data: members, error} = await client.rpc('nexo_list_members', {p_organization_id: organization.id});
    if (!error && members) result.registeredUsers.push(...members as Row[]);
    else for(const project of result.projects.filter(p=>p.organization_id===organization.id)){const response=await client.rpc('nexo_list_project_users',{p_project_id:project.id});if(!response.error&&response.data)for(const member of response.data as Row[])if(!result.registeredUsers.some(m=>m.id===member.id))result.registeredUsers.push(member);}
  }));
  return result;
}
