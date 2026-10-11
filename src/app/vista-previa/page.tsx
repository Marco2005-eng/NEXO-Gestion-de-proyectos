import {WorkspaceSelectionProvider} from '@/features/workspace/components/selection-provider';
import { AppShell } from '@/components/layout/app-shell';
import { Workspace } from '@/features/workspace/components/workspace';
import { previewData } from '@/features/workspace/infrastructure/preview-data';
export default async function Preview({searchParams}:{searchParams:Promise<{modulo?:string}>}) {
  const {modulo}=await searchParams;
  return <WorkspaceSelectionProvider data={previewData}><AppShell connected={false}><Workspace key={modulo??'resumen'} data={previewData} module={modulo??'resumen'}/></AppShell></WorkspaceSelectionProvider>;
}
