import {requireUser} from '@/features/auth/application/session';
import {loadWorkspace} from '@/features/workspace/infrastructure/load-workspace';
import {OrganizationManagement} from '@/features/administration/components/organization-management';
export default async function SystemPage(){
 const {client}=await requireUser();const check=await client.rpc('nexo_is_platform_admin');
 if(check.error||!check.data)return <div className="page-content"><h1>Administración del sistema</h1><p>Esta sección es exclusiva del superadministrador de Nexo.</p></div>;
 const data=await loadWorkspace();const users=await client.rpc('nexo_platform_users');
 return <div className="page-content"><OrganizationManagement system data={data} organizationId={String(data.organizations[0]?.id??'')} users={users.data??[]}/></div>;
}
