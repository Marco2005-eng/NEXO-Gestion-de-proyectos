export type Row = Record<string, string | number | boolean | null>;
export type Grant = { organizationId: string; scope: string; projectId: string | null; areaId: string | null; codes: string[] };
export type WorkspaceData = {
  connected: boolean; userId: string; userName: string; grants: Grant[];
  organizations: Row[]; projects: Row[]; tasks: Row[]; materials: Row[];
  inventory: Row[]; requests: Row[]; requestItems: Row[]; history: Row[];
  approvals: Row[]; documents: Row[]; diagrams: Row[]; areas: Row[];
  warehouses: Row[]; members: Row[]; profiles: Row[]; assignees: Row[];
  summaries: Row[]; roles: Row[]; notifications: Row[]; errors: string[];
  projectMembers: Row[]; registeredUsers: Row[]; registrationEnabled: boolean;
  permissions?: Row[]; rolePermissions?: Row[]; roleAssignments?: Row[];
  platformAdmin?: boolean; taskSubmissions?: Row[]; taskEvidence?: Row[]; taskReviewers?: Row[];
};
export function hasGrant(grants: Grant[], code: string, organizationId: string, projectId?: string | null, areaId?: string | null) {
  return grants.some(g => g.organizationId === organizationId && g.codes.includes(code) &&
    (g.scope === 'organization' || (code === 'project.create' && g.scope === 'project') || (g.scope === 'project' && !!projectId && g.projectId === projectId) || (g.scope === 'area' && !!areaId && g.areaId === areaId)));
}
