import {test} from 'node:test';
import assert from 'node:assert/strict';
import {automaticReview} from '../src/features/tasks/automatic-review';
test('la comprobación admite acentos, informa archivos y no certifica el cumplimiento',()=>{
 const checks=automaticReview({summary:'Instalé conexiones LAN y comprobé la conectividad de todos los puntos.',criteria_snapshot:'Instalar conexiones LAN y comprobar conectividad.',requested_progress:50},[{mime_type:'image/jpeg',file_size:512}]);
 assert.equal(checks.filter(c=>c.observation).length,0);
 assert.match(checks.find(c=>c.id==='criteria')!.detail,/no confirma el cumplimiento/);
 assert.match(checks.find(c=>c.id==='evidence')!.detail,/Abre los archivos/);
});
test('redacción distinta o breve genera observaciones, sin rechazar la entrega',()=>{
 const checks=automaticReview({summary:'Listo el cableado.',criteria_snapshot:'Implementar el área de redes.',requested_progress:100},[{mime_type:'image/png',file_size:256}]);
 assert.equal(checks.find(c=>c.id==='criteria')!.observation,true);
 assert.equal(checks.find(c=>c.id==='description')!.observation,true);
 assert.match(checks.find(c=>c.id==='criteria')!.detail,/otra redacción/);
 assert.equal(checks.find(c=>c.id==='progress')!.observation,false);
 assert.ok(!checks.some(c=>'decision' in c));
});
test('informa metadatos incompletos y porcentajes ausentes sin tratarlos como cero',()=>{
 const checks=automaticReview({summary:'',criteria_snapshot:'',requested_progress:null},[{mime_type:'image/jpeg',file_size:null}]);
 assert.equal(checks.filter(c=>c.observation).length,4);
 assert.equal(automaticReview({summary:'Entrega',requested_progress:120},[]).find(c=>c.id==='progress')!.observation,true);
});
