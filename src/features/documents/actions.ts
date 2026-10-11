'use server';
import {requireUser} from '@/features/auth/application/session';
import {loadWorkspace} from '@/features/workspace/infrastructure/load-workspace';
import {hasGrant} from '@/features/workspace/domain/types';
export async function documentTeam(projectId:string){
 const {client}=await requireUser();const workspace=await loadWorkspace();const project=workspace.projects.find(p=>p.id===projectId);
 if(!project||!hasGrant(workspace.grants,'document.manage',String(project.organization_id),projectId,project.area_id as string|null))return {members:[],error:'No tienes permiso para compartir documentos en este proyecto.'};
 const members:{id:string;name:string;job:string}[]=[];
 for(let offset=0;;offset+=500){
  const {data,error}=await client.from('project_members').select('id,member_id,organization_members!inner(id,status,job_title,profiles!organization_members_user_id_fkey(display_name))').eq('project_id',projectId).is('left_at',null).eq('organization_members.status','active').order('id').range(offset,offset+499);
  if(error)return {members:[],error:'No se pudo consultar el equipo del proyecto. Vuelve a intentar.'};
  for(const row of (data??[]) as unknown as {member_id:string;organization_members:{job_title:string|null;profiles:{display_name:string|null}}}[])members.push({id:row.member_id,name:row.organization_members.profiles?.display_name||'Colaborador',job:row.organization_members.job_title||''});
  if(!data?.length||data.length<500)break;
 }
 return {members,error:''};
}
export async function listDocuments(organizationId:string){
 const {client}=await requireUser();const {data,error}=await client.rpc('nexo_documents',{p_organization_id:organizationId});
 return {data:data??[],error:error?(error.code==='PGRST202'?'Ejecuta supabase/17_documentos_restringidos.sql para activar documentos privados.':error.message):''};
}
export async function documentCommand(command:string,payload:Record<string,unknown>){
 const {client}=await requireUser();const {error}=await client.rpc('nexo_document_command',{p_command:command,p_payload:payload});
 return {ok:!error,message:error?.message??'Cambios guardados.'};
}
export async function documentUrl(versionId:string,download=true){
 const {client}=await requireUser();const {data,error}=await client.from('document_versions').select('storage_path,file_name,mime_type').eq('id',versionId).single();
 if(error||!data)return {url:'',error:'No tienes acceso a esta versión.'};
 const response=await client.storage.from('restricted-documents').createSignedUrl(data.storage_path,60,download?{download:data.file_name}:{});
 return {url:response.data?.signedUrl??'',error:response.error?'No se pudo descargar el archivo.':''};
}

