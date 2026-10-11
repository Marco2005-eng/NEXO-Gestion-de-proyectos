import 'server-only';
import { requireUser } from '@/features/auth/application/session';
import type { RecordRow } from '@/components/shared/record-list';
export async function listReports(): Promise<RecordRow[]> {
  const { client } = await requireUser();
  const { data, error } = await client.from('project_progress_summary').select('project_id,name,total_tasks,completed_tasks,progress_percent').limit(100);
  if (error) throw new Error('No se pudo consultar el módulo reportes.');
  return (data ?? []) as unknown as RecordRow[];
}
