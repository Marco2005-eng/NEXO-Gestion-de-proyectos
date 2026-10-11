import type {Grant} from './types';
const permissions:Record<string,string[]>={
 proyectos:['project.view'],tareas:['task.view'],materiales:['material.view'],
 solicitudes:['material.request','material.approve','material.manage_stock','audit.view'],
 aprobaciones:['approval.view'],documentos:['document.view'],diagramas:['diagram.view'],reportes:['report.view'],
 administracion:['user.manage','user.invite','access.manage','project.manage','organization.manage'],
};
export function canOpenModule(grants:Grant[],module:string,organizationId?:string){
 if(module==='resumen')return true;
 return grants.some(g=>(!organizationId||g.organizationId===organizationId)&&(permissions[module]??[]).some(code=>g.codes.includes(code)));
}
