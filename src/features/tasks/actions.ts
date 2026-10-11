'use server';
import {requireUser} from '@/features/auth/application/session';
import {revalidatePath} from 'next/cache';
export async function taskCommand(command:string,payload:Record<string,unknown>){
 const {client}=await requireUser();if(!['task.team','task.configure','task.progress','task.submit','task.review'].includes(command))return {ok:false,message:'Operación inválida.'};
 const {error}=await client.rpc('nexo_task_command',{p_command:command,p_payload:payload});
 if(error)return {ok:false,message:error.code==='PGRST202'?'Ejecuta supabase/13_entregas_revision_tareas.sql y supabase/14_avances_equipo_revision.sql para activar este flujo.':error.message};
 revalidatePath('/','layout');return {ok:true,message:command==='task.submit'?'Entrega enviada a revisión.':command==='task.review'?'Revisión registrada.':'Cambios guardados.'};
}
export async function evidenceUrl(id:string){
 const {client}=await requireUser();const file=await client.from('task_evidence').select('storage_path,mime_type,file_name').eq('id',id).single();
 if(file.error||!file.data)return {ok:false as const,message:'No tienes acceso a esta evidencia.'};
 const result=await client.storage.from('task-evidence').createSignedUrl(file.data.storage_path,600);
 if(result.error)return {ok:false as const,message:'No se pudo abrir la evidencia. Intenta de nuevo.'};
 return {ok:true as const,url:result.data.signedUrl,mime:String(file.data.mime_type),name:String(file.data.file_name)};
}
