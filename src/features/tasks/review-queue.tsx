'use client';
import type {Row,WorkspaceData} from '@/features/workspace/domain/types';
import {taskReviewAccess} from './review-access';
export function ReviewQueue({data,organizationId,projectId='all',onReview}:{data:WorkspaceData;organizationId:string;projectId?:string;onReview:(task:Row)=>void}){
 const projects=data.projects.filter(p=>p.organization_id===organizationId);
 const tasks=data.tasks.filter(t=>projects.some(p=>p.id===t.project_id)&&(projectId==='all'||t.project_id===projectId));
 const deliveries=tasks.filter(t=>taskReviewAccess(t,data).canReview);
 const supervisor=tasks.some(t=>taskReviewAccess(t,data).reviewer);
 if(!supervisor)return null;
 return <section className="review-queue panel" aria-label="Supervisión de avances"><div className="task-delivery-heading"><div><h2>Avances pendientes de revisión</h2><p className="muted">Revisa las fotos de cada entrega y valida el avance del colaborador.</p></div><span className="tag">{deliveries.length} pendientes</span></div>{deliveries.map(t=>{const pending=taskReviewAccess(t,data).pending!;const project=projects.find(p=>p.id===t.project_id);const area=data.areas.find(a=>a.id===(t.area_id??project?.area_id));return <article className="review-queue-row" key={String(t.id)}><div><strong>{t.title}</strong><small>{project?.name} · {area?.name??'Sin área'} · {data.profiles.find(p=>p.id===pending.submitted_by)?.display_name??'Colaborador'}</small><span>Avance solicitado: {pending.requested_progress??100} % · {(data.taskEvidence??[]).filter(e=>e.submission_id===pending.id).length} evidencias</span></div><button className="button primary" onClick={()=>onReview(t)}>Revisar avance</button></article>;})}{!deliveries.length&&<p className="form-help">No tienes entregas pendientes en esta selección. La revisión aparece cuando el colaborador pulsa «Enviar a revisión» con su porcentaje y las evidencias. Si ejecutas esa tarea, otro supervisor debe revisarla.</p>}</section>;
}
