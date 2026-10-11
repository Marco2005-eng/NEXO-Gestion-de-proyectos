'use server';
import {requireUser} from '@/features/auth/application/session';
export async function loadProjectBalance(projectId:string){
 const {client}=await requireUser();const {data,error}=await client.rpc('nexo_project_balance',{p_project_id:projectId});
 if(error)throw new Error(['PGRST202','42883'].includes(error.code)?'Ejecuta supabase/21_inversion_materiales_presupuesto.sql para habilitar el balance.':error.message);
 return data;
}
