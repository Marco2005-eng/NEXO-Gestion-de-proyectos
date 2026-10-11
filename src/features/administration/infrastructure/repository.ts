import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listAdministration(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('areas').select('id,code,name').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo administración.');
  return (data ?? []) as unknown as RecordRow[];
}
