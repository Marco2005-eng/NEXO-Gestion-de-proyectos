'use server';
import {requireUser} from '@/features/auth/application/session';
export type KardexRow={
 id:string;occurred_at:string;movement_type_code:string;movement_type_name:string;
 material_id:string;sku:string;material_name:string;unit_of_measure:string;
 warehouse_id:string;warehouse_name:string;quantity:number;quantity_delta:number;
 balance_after:number;reserved_delta:number;reserved_balance_after:number;
 reference_type:string|null;reference_id:string|null;request_id:string|null;
 request_number:string|null;reason:string|null;recorded_by:string|null;recorded_by_name:string;
};
export async function loadMaterialKardex(projectId:string,materialId?:string|null){
 const {client}=await requireUser();
 const {data,error}=await client.rpc('nexo_material_kardex',{p_project_id:projectId,p_material_id:materialId||null,p_type:null,p_from:null,p_to:null,p_limit:100,p_offset:0});
 if(error)throw new Error(['PGRST202','42883'].includes(error.code)?'Ejecuta supabase/22_materiales_flujo_completo.sql para habilitar el kardex.':error.message);
 return data as {total:number;limit:number;offset:number;rows:KardexRow[]};
}
