'use client';
import {createContext,useCallback,useContext,useEffect,useMemo,useState} from 'react';
import {parseSelection,resolveSelection,type Selection} from '../domain/selection';
import type {WorkspaceData} from '../domain/types';
type Context={organizationId:string;projectId:string;ready:boolean;setOrganizationId:(id:string)=>void;setProjectId:(id:string)=>void};
const SelectionContext=createContext<Context|null>(null);
export function WorkspaceSelectionProvider({data,children}:{data:Pick<WorkspaceData,'userId'|'organizations'|'projects'>;children:React.ReactNode}){
 const key='nexo.workspace.selection.v1:'+data.userId;
 const [selection,setSelection]=useState<Selection>({organizationId:'',projects:{}});
 const [loadedKey,setLoadedKey]=useState('');
 useEffect(()=>{let restored=parseSelection(null);try{restored=parseSelection(localStorage.getItem(key));}catch{}setSelection(restored);setLoadedKey(key);},[key]);
 const ready=loadedKey===key;
 const {organizationId,projectId}=resolveSelection(ready?selection:parseSelection(null),data.organizations,data.projects);
 useEffect(()=>{if(!ready)return;try{localStorage.setItem(key,JSON.stringify({...selection,organizationId,projects:{...selection.projects,[organizationId]:projectId}}));}catch{}},[ready,key,selection,organizationId,projectId]);
 const setOrganizationId=useCallback((id:string)=>{if(data.organizations.some(o=>o.id===id))setSelection(old=>({...old,organizationId:id}));},[data.organizations]);
 const setProjectId=useCallback((id:string)=>{if(id==='all'||data.projects.some(p=>p.id===id&&p.organization_id===organizationId))setSelection(old=>({...old,organizationId,projects:{...old.projects,[organizationId]:id}}));},[data.projects,organizationId]);
 const value=useMemo(()=>({organizationId,projectId,ready,setOrganizationId,setProjectId}),[organizationId,projectId,ready,setOrganizationId,setProjectId]);
 return <SelectionContext.Provider value={value}>{children}</SelectionContext.Provider>;
}
export function useWorkspaceSelection(){const value=useContext(SelectionContext);if(!value)throw new Error('Falta el contexto del espacio de trabajo.');return value;}
