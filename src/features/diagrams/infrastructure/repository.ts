import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listDiagrams(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('activity_diagrams').select('id,name,created_at').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo diagramas.');
  return (data ?? []) as unknown as RecordRow[];
}
