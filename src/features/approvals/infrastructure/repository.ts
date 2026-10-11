import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listApprovals(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('approval_instances').select('id,status_code,created_at').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo aprobaciones.');
  return (data ?? []) as unknown as RecordRow[];
}
