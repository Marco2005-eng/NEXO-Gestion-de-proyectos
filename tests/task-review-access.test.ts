import {test} from 'node:test';
import assert from 'node:assert/strict';
import {taskReviewAccess} from '../src/features/tasks/review-access';
import {previewData} from '../src/features/workspace/infrastructure/preview-data';
const task={id:'pending-task',project_id:'p1',status_code:'in_review'};
const base={...previewData,assignees:[],taskSubmissions:[{id:'delivery',task_id:'pending-task',submitted_by:'employee',status:'pending',requested_progress:50}]};
test('el jefe y el proveedor con permiso ven la aprobación aunque no tengan asignación de revisor',()=>{
 assert.equal(taskReviewAccess(task,base).canReview,true);
 assert.equal(taskReviewAccess(task,{...base,members:[],projectMembers:[],taskReviewers:[]}).canReview,true);
});
test('un ejecutor o autor de la entrega no ve la aprobación de su propio trabajo',()=>{
 const own={...base,assignees:[{task_id:task.id,member_id:'member1',assignment_type:'responsible'}]};
 assert.equal(taskReviewAccess(task,own).canReview,false);
 assert.equal(taskReviewAccess(task,{...base,taskSubmissions:[{...base.taskSubmissions[0],submitted_by:previewData.userId}]}).canReview,false);
});
test('el revisor asignado necesita pertenecer activamente al proyecto; el auditor consulta sin aprobar',()=>{
 const assigned={...base,grants:[],assignees:[{task_id:task.id,member_id:'member1',assignment_type:'reviewer'}]};
 assert.equal(taskReviewAccess(task,assigned).canReview,true);
 assert.equal(taskReviewAccess(task,{...assigned,projectMembers:[]}).canReview,false);
 assert.equal(taskReviewAccess(task,{...base,grants:[]}).canReview,false);
});
test('la aprobación aparece únicamente con una entrega pendiente en revisión',()=>{
 assert.equal(taskReviewAccess(task,{...base,taskSubmissions:[]}).canReview,false);
 assert.equal(taskReviewAccess({...task,status_code:'in_progress'},base).canReview,false);
 assert.equal(taskReviewAccess(task,{...base,taskSubmissions:[{...base.taskSubmissions[0],status:'approved'}]}).canReview,false);
});
