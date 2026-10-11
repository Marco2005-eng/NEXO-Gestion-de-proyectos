'use server';
import {requireUser} from '@/features/auth/application/session';
import {revalidatePath} from 'next/cache';
export async function updatePersonalProfile(form:FormData){
 const {client}=await requireUser();
 const payload=Object.fromEntries(['display_name','first_name','last_name','phone','identity_type','identity_number'].map(k=>[k,String(form.get(k)??'')]));
 const {error}=await client.rpc('nexo_update_personal_profile',{p_payload:payload});
 if(error)return {ok:false,message:error.code==='PGRST202'?'Ejecuta supabase/09_perfil_personal.sql para habilitar el guardado del perfil.':error.message};
 revalidatePath('/','layout');return {ok:true,message:'Perfil actualizado.'};
}
