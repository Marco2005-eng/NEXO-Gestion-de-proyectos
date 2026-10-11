'use server';
import {requireUser} from '@/features/auth/application/session';
import {loadWorkspace} from '../infrastructure/load-workspace';
import {hasGrant,type Row} from '../domain/types';
import {revalidatePath} from 'next/cache';
export async function createProjectArea(organizationId:string,rawName:string):Promise<{ok:boolean;message:string;area?:Row}>{
 const {client,user}=await requireUser();const data=await loadWorkspace();
 if(!hasGrant(data.grants,'area.manage',organizationId))return {ok:false,message:'Solo quien administra las áreas de esta organización puede registrarlas.'};
 const name=rawName.trim().replace(/\s+/g,' ');
 if(!name||name.length>120)return {ok:false,message:'Escribe un nombre de área de hasta 120 caracteres.'};
 const normalize=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es');
 const existing=data.areas.find(a=>a.organization_id===organizationId&&normalize(String(a.name))===normalize(name));
 if(existing)return {ok:true,message:'Área existente seleccionada.',area:existing};
 const prefix=name.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,25)||'AREA';
 const {data:area,error}=await client.from('areas').insert({organization_id:organizationId,name,code:`${prefix}-${crypto.randomUUID().slice(0,8)}`,created_by:user.id}).select('id,organization_id,name,code').single();
 if(error)return {ok:false,message:'No se pudo registrar el área: '+error.message};
 revalidatePath('/','layout');return {ok:true,message:'Área registrada.',area:area as Row};
}
