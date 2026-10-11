import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listMaterials(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('inventory_availability').select('material_id,warehouse_id,name,warehouse_name,available').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo materiales.');
  return (data ?? []) as unknown as RecordRow[];
}
