import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listProjects(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('projects').select('id,code,name,status_code').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo proyectos.');
  return (data ?? []) as unknown as RecordRow[];
}
