import {test} from 'node:test';
import assert from 'node:assert/strict';
import {parseSelection,resolveSelection} from '../src/features/workspace/domain/selection';
const organizations=[{id:'o1'},{id:'o2'}];
const projects=[{id:'p1',organization_id:'o1'},{id:'p2',organization_id:'o1'},{id:'p3',organization_id:'o2'}];
test('mantiene la organización y el proyecto al restaurar la selección',()=>{
 const persisted=JSON.stringify({organizationId:'o1',projects:{o1:'p2',o2:'p3'}});
 const restored=parseSelection(persisted);
 assert.deepEqual(resolveSelection(restored,organizations,projects),{organizationId:'o1',projectId:'p2'});
 assert.deepEqual(resolveSelection({...restored,organizationId:'o2'},organizations,projects),{organizationId:'o2',projectId:'p3'});
 assert.deepEqual(resolveSelection(restored,organizations,projects),{organizationId:'o1',projectId:'p2'});
});
test('no restaura proyectos de otra organización ni aquellos sin acceso',()=>{
 assert.equal(resolveSelection({organizationId:'o1',projects:{o1:'p3'}},organizations,projects).projectId,'p1');
 assert.deepEqual(resolveSelection({organizationId:'o2',projects:{o2:'p3'}},[{id:'o1'}],projects.filter(p=>p.organization_id==='o1')),{organizationId:'o1',projectId:'p1'});
 assert.equal(resolveSelection({organizationId:'o1',projects:{o1:'p2'}},organizations,projects.filter(p=>p.id!=='p2')).projectId,'p1');
});
test('conserva Todos los proyectos y tolera preferencias dañadas o un espacio vacío',()=>{
 assert.equal(resolveSelection(parseSelection('{"organizationId":"o1","projects":{"o1":"all"}}'),organizations,projects).projectId,'all');
 assert.deepEqual(resolveSelection(parseSelection('invalid'),organizations,projects),{organizationId:'o1',projectId:'p1'});
 assert.deepEqual(resolveSelection(parseSelection(null),[],[]),{organizationId:'',projectId:'all'});
 assert.deepEqual(parseSelection('{"organizationId":20,"projects":[]}'),{organizationId:'',projects:{}});
});
