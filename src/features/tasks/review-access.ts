import {hasGrant,type Row,type WorkspaceData} from '@/features/workspace/domain/types';
export function taskReviewAccess(task:Row,data:WorkspaceData){
 const project=data.projects.find(p=>p.id===task.project_id);
 const members=data.members.filter(m=>m.user_id===data.userId&&m.status==='active').map(m=>m.id);
 const activeTeam=(memberId:unknown)=>data.projectMembers.some(pm=>pm.project_id===task.project_id&&pm.member_id===memberId&&!pm.left_at);
 const worker=data.assignees.some(a=>a.task_id===task.id&&members.includes(a.member_id)&&activeTeam(a.member_id)&&['responsible','collaborator'].includes(String(a.assignment_type)));
 const manager=!!project&&hasGrant(data.grants,'task.manage',String(project.organization_id),String(project.id),(task.area_id??project.area_id) as string|null);
 const reviewer=manager||data.assignees.some(a=>a.task_id===task.id&&members.includes(a.member_id)&&activeTeam(a.member_id)&&a.assignment_type==='reviewer');
 const pending=data.taskSubmissions?.find(s=>s.task_id===task.id&&s.status==='pending');
 return {worker,manager,reviewer,pending,canReview:!!pending&&task.status_code==='in_review'&&reviewer&&!worker&&pending.submitted_by!==data.userId};
}
