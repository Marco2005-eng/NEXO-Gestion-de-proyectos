import type {Row} from './types';
export type Selection={organizationId:string;projects:Record<string,string>};
export function resolveSelection(selection:Selection,organizations:Row[],projects:Row[]){
 const organizationId=organizations.some(o=>o.id===selection.organizationId)?selection.organizationId:String(organizations[0]?.id??'');
 const available=projects.filter(p=>p.organization_id===organizationId);
 const saved=selection.projects[organizationId];
 const projectId=saved==='all'||available.some(p=>p.id===saved)?saved:String(available[0]?.id??'all');
 return {organizationId,projectId};
}
export function parseSelection(raw:string|null):Selection{
 try{const value=JSON.parse(raw??'null');return {organizationId:typeof value?.organizationId==='string'?value.organizationId:'',projects:value?.projects&&typeof value.projects==='object'&&!Array.isArray(value.projects)?Object.fromEntries(Object.entries(value.projects).filter(([key,id])=>key!=='__proto__'&&typeof id==='string')) as Record<string,string>:{}};}catch{return {organizationId:'',projects:{}};}
}
