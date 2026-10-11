'use server';
import { revalidatePath } from 'next/cache';
import { requireUser } from '@/features/auth/application/session';
import { loadWorkspace } from '@/features/workspace/infrastructure/load-workspace';
import { hasGrant } from '@/features/workspace/domain/types';
import { createAdminClient } from '@/lib/supabase/admin';
import type { MutationResult } from '@/features/workspace/application/actions';
export async function organizationCommand(command:string,payload:Record<string,unknown>):Promise<MutationResult>{
 const {client}=await requireUser();
 if(!['organization.create','organization.rename','project.lead'].includes(command))return {ok:false,message:'Operación inválida.'};
 const {error}=await client.rpc('nexo_organization_command',{p_command:command,p_payload:payload});
 if(error)return {ok:false,message:error.code==='PGRST202'?'Ejecuta supabase/11_organizaciones_superadministrador.sql para habilitar esta función.':error.code==='23505'?'Ya existe una organización con ese código.':error.message};
 revalidatePath('/','layout');return {ok:true,message:command==='project.lead'?'Jefe de proyecto asignado.':command==='organization.create'?'Organización creada con su administrador.':'Nombre de organización actualizado.'};
}
export async function registerUser(form: FormData): Promise<MutationResult> {
  const {user,client}=await requireUser();
  const organizationId=String(form.get('organization_id')??'');
  const workspace=await loadWorkspace();
  const organizationInvite=hasGrant(workspace.grants,'user.invite',organizationId);
  const requestedProject=workspace.projects.find(p=>p.id===form.get('project_id')&&p.organization_id===organizationId);
  const projectInvite=!!requestedProject&&hasGrant(workspace.grants,'user.invite',organizationId,String(requestedProject.id),requestedProject.area_id as string|null)&&hasGrant(workspace.grants,'project.manage',organizationId,String(requestedProject.id),requestedProject.area_id as string|null);
  if(!organizationInvite&&!projectInvite)return {ok:false,message:'Solo puedes registrar colaboradores en un proyecto que administras.'};
  const email=String(form.get('email')??'').trim().toLowerCase();
  const name=String(form.get('display_name')??'').trim();
  const password=String(form.get('password')??'');
  const jobTitle=String(form.get('job_title')??'').trim();
  const projectId=String(form.get('project_id')??'').trim();
  const roleCode=String(form.get('role_code')??'member');
  if(projectId){
    const project=workspace.projects.find(p=>p.id===projectId&&p.organization_id===organizationId);
    if(!project||!hasGrant(workspace.grants,'project.manage',organizationId,projectId,project.area_id as string|null))return {ok:false,message:'No tienes permiso para agregar usuarios a ese proyecto.'};
    if(!workspace.roles.some(r=>r.organization_id===organizationId&&r.code===roleCode&&r.is_active&&r.code!=='admin'))return {ok:false,message:'Selecciona un rol de proyecto válido.'};
    if(roleCode!=='member'&&!hasGrant(workspace.grants,'access.manage',organizationId,projectId,project.area_id as string|null))return {ok:false,message:'No tienes permiso para asignar ese rol.'};
  }
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!name||name.length>150||password.length<10||password.length>128||jobTitle.length>200) return {ok:false,message:'Revisa nombre, correo y contraseña (mínimo 10 caracteres).'};
  // Verifica que la migración esté instalada antes de crear una cuenta en Auth.
  const check=organizationInvite?await client.rpc('nexo_list_members',{p_organization_id:organizationId}):await client.rpc('nexo_list_project_users',{p_project_id:requestedProject!.id});
  if(check.error)return {ok:false,message:organizationInvite?'Ejecuta supabase/06_usuarios_asignaciones.sql antes de registrar usuarios.':'Ejecuta supabase/11_organizaciones_superadministrador.sql para habilitar el registro de colaboradores.'};
  try {
    const admin=createAdminClient();
    const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{display_name:name}});
    if(error||!data.user) return {ok:false,message:error?.code==='email_exists'?'El correo ya está registrado en Supabase.':'No se pudo crear la cuenta. Comprueba que el correo no exista y que la contraseña cumpla las reglas de Supabase.'};
    const linked=organizationInvite?await admin.rpc('nexo_attach_registered_user',{p_organization_id:organizationId,p_user_id:data.user.id,p_actor_id:user.id,p_job_title:jobTitle}):await admin.rpc('nexo_attach_project_user',{p_organization_id:organizationId,p_user_id:data.user.id,p_actor_id:user.id,p_job_title:jobTitle,p_project_id:projectId});
    if(linked.error){
      // Compensación solo de la cuenta que acaba de crear esta misma operación.
      const cleanup=await admin.auth.admin.deleteUser(data.user.id);
      return {ok:false,message:cleanup.error?'Se creó la cuenta, pero no pudo vincularse. Revisa Authentication y la organización antes de reintentar.':'No pudo vincularse la cuenta a la organización; el registro se revirtió.'};
    }
    if(!organizationInvite){revalidatePath('/','layout');return {ok:true,message:'Colaborador registrado y asignado a tu proyecto.'};}
    if(projectId){
      const assigned=await client.rpc('nexo_team_command',{p_command:'project.add',p_payload:{project_id:projectId,member_id:linked.data,role_code:roleCode,project_title:jobTitle}});
      revalidatePath('/','layout');
      if(assigned.error)return {ok:true,message:'Usuario creado, pero no se pudo asignar el proyecto. Agrégalo desde Equipo por proyecto; no vuelvas a registrar la cuenta.'};
      return {ok:true,message:'Usuario registrado y agregado al proyecto con su rol.'};
    }
    revalidatePath('/','layout');
    return {ok:true,message:'Usuario registrado. Ahora agrégalo al equipo de un proyecto para otorgarle acceso.'};
  }catch(error){return {ok:false,message:error instanceof Error?error.message:'No se pudo registrar el usuario.'};}
}
export async function assignTeam(command:string,payload:Record<string,unknown>):Promise<MutationResult>{
  const {client}=await requireUser();
  if(!['project.add','task.assign'].includes(command))return {ok:false,message:'Operación inválida.'};
  const {error}=await client.rpc('nexo_team_command',{p_command:command,p_payload:payload});
  if(error)return {ok:false,message:error.code==='PGRST202'?'Ejecuta supabase/06_usuarios_asignaciones.sql para habilitar las asignaciones.':error.message};
  revalidatePath('/','layout');
  return {ok:true,message:command==='project.add'?'Usuario agregado al proyecto con su rol.':'Responsable de la tarea actualizado.'};
}
export async function manageRole(command:string,payload:Record<string,unknown>):Promise<MutationResult>{
  const {client}=await requireUser();
  if(!['role.save','role.assign','role.replace','role.revoke'].includes(command))return {ok:false,message:'Operación inválida.'};
  const {error}=await client.rpc('nexo_role_command',{p_command:command,p_payload:payload});
  if(error)return {ok:false,message:command==='role.replace'&&error.message.includes('inválida')?'Ejecuta supabase/08_cambiar_roles.sql para habilitar el cambio de rol.':error.code==='PGRST202'?'Ejecuta supabase/07_notificaciones_roles.sql para habilitar esta función.':error.message};
  revalidatePath('/','layout');return {ok:true,message:'Roles actualizados.'};
}
