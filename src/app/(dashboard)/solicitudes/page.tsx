import { loadWorkspace } from '@/features/workspace/infrastructure/load-workspace';
import { Workspace } from '@/features/workspace/components/workspace';
export default async function Page() {
  return <Workspace module="solicitudes" data={await loadWorkspace()} />;
}
