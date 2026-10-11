import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listRequests(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('material_request_tracking').select('request_id,request_number,project_name,status_code').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo solicitudes.');
  return (data ?? []) as unknown as RecordRow[];
}
