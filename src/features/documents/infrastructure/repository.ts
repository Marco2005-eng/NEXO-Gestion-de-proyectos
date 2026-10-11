import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listDocuments(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('documents').select('id,title,created_at').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo documentos.');
  return (data ?? []) as unknown as RecordRow[];
}
