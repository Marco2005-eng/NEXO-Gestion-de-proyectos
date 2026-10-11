import {WorkspaceSelectionProvider} from '@/features/workspace/components/selection-provider';
import { AppShell } from '@/components/layout/app-shell';
import { getSupabaseConfig } from '@/lib/supabase/config';
import {loadWorkspace} from '@/features/workspace/infrastructure/load-workspace';
import { requireUser } from '@/features/auth/application/session';
export const dynamic = 'force-dynamic';
export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const connected = Boolean(getSupabaseConfig());
  if (connected) await requireUser();
  const data=connected?await loadWorkspace():null;
  const grants=data?.grants??[];
  return <WorkspaceSelectionProvider key={data?.userId??'offline'} data={data??{userId:'offline',organizations:[],projects:[]}}><AppShell connected={connected} grants={grants} platformAdmin={data?.platformAdmin}>{children}</AppShell></WorkspaceSelectionProvider>;
}
