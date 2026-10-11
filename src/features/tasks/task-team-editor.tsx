'use client';
import {useState,useTransition} from 'react';
import {useRouter} from 'next/navigation';
import type {Row,WorkspaceData} from '@/features/workspace/domain/types';
import {taskCommand} from './actions';

export function TaskTeamEditor({task,data}:{task:Row;data:WorkspaceData}){
 const router=useRouter();const [busy,start]=useTransition();const [message,setMessage]=useState('');
 const assigned=data.assignees.filter(a=>a.task_id===task.id);
 const [responsible,setResponsible]=useState(String(assigned.find(a=>a.assignment_type==='responsible')?.member_id??''));
 const [collaborators,setCollaborators]=useState(assigned.filter(a=>a.assignment_type==='collaborator').map(a=>String(a.member_id)));
 const [reviewer,setReviewer]=useState(String(assigned.find(a=>a.assignment_type==='reviewer')?.member_id??''));
 const ids=data.projectMembers.filter(pm=>pm.project_id===task.project_id&&!pm.left_at).map(pm=>pm.member_id);
 const team=data.members.filter(m=>ids.includes(m.id)&&m.status==='active');
 const automaticReviewers=(data.taskReviewers??[]).filter(r=>r.task_id===task.id&&r.source==='manager'&&r.member_id!==responsible&&!collaborators.includes(String(r.member_id)));
 const name=(id:unknown)=>{const member=data.members.find(m=>m.id===id);return String(data.profiles.find(p=>p.id===member?.user_id)?.display_name??'Usuario');};
 return <form className="task-team-editor" onSubmit={e=>{e.preventDefault();start(async()=>{if(!data.connected){setMessage('Inicia sesión para guardar el equipo.');return;}try{const response=await taskCommand('task.team',{task_id:task.id,responsible_member_id:responsible,collaborator_member_ids:collaborators,reviewer_member_id:reviewer});setMessage(response.message);if(response.ok)router.refresh();}catch{setMessage('No se pudo guardar el equipo. Revisa la conexión.');}});}}>
 <p className="form-help">Elige integrantes activos del proyecto. Un ejecutor no puede revisar su propia tarea. Los jefes y usuarios con permiso para gestionar tareas quedan habilitados para revisar. No necesitas elegirlos en cada tarea.</p>
 <label>Responsable<select required value={responsible} disabled={busy} onChange={e=>{setResponsible(e.target.value);setCollaborators(old=>old.filter(id=>id!==e.target.value));if(reviewer===e.target.value)setReviewer('');}}><option value="">Selecciona un responsable</option>{team.map(m=><option key={String(m.id)} value={String(m.id)}>{name(m.id)}</option>)}</select></label>
 <fieldset><legend>Colaboradores que ejecutan la tarea (opcional)</legend>{team.filter(m=>m.id!==responsible).map(m=><label className="delivery-checkbox" key={String(m.id)}><input type="checkbox" checked={collaborators.includes(String(m.id))} disabled={busy} onChange={e=>{const id=String(m.id);setCollaborators(old=>e.target.checked?[...old,id]:old.filter(v=>v!==id));if(e.target.checked&&reviewer===id)setReviewer('');}}/>{name(m.id)}</label>)}{team.length<2&&<p className="form-help">Agrega otros usuarios en Equipo por proyecto si necesitas colaboradores o un revisor adicional.</p>}</fieldset>
 <div className="delivery-criteria"><strong>Supervisores según su rol</strong><p className="form-help">Revisan los jefes y cargos con permiso para gestionar tareas dentro de este proyecto, excepto quienes ejecutan esta tarea. La lista se actualiza con sus permisos.</p>{automaticReviewers.length>0?<ul className="reviewer-list">{automaticReviewers.map(r=><li key={String(r.user_id)}>{r.display_name}</li>)}</ul>:<p className="form-help">Al guardar se comprobará que haya un supervisor disponible. Si todos ejecutan esta tarea, elige un revisor adicional.</p>}</div>
 <details className="delivery-settings" open={!!reviewer}><summary>Elegir un revisor adicional (opcional)</summary><label>Revisor adicional<select value={reviewer} disabled={busy} onChange={e=>setReviewer(e.target.value)}><option value="">Usar los supervisores del proyecto</option>{team.filter(m=>m.id!==responsible&&!collaborators.includes(String(m.id))).map(m=><option key={String(m.id)} value={String(m.id)}>{name(m.id)}</option>)}</select></label><p className="form-help">Puedes añadir otro integrante cuando necesites una revisión específica. Los jefes autorizados conservan la supervisión.</p></details>
 <button className="button primary" disabled={busy||!responsible}>{busy?'Guardando…':'Guardar equipo de la tarea'}</button>{message&&<p className="notice" role="status">{message}</p>}
 </form>;
}
