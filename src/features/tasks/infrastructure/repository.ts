import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listTasks(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('tasks').select('id,title,status_code,priority_code').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo tareas.');
  return (data ?? []) as unknown as RecordRow[];
}
