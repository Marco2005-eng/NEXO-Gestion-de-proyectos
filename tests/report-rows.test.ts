import type {Row} from '../src/features/workspace/domain/types';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildReport,reportCsv,reportDay} from '../src/features/reports/domain/report-rows';
test('reportes: entregas por fecha y costo guardado, sin contar reservas como gastos',()=>{
 const source:Record<string,Row[]>={projects:[{id:'p',name:'Red'}],materials:[{id:'m',name:'Cable',unit_of_measure:'metros',standard_cost:999}],requests:[{id:'r',request_number:'SOL-1',project_id:'p'}],items:[{id:'i',request_id:'r',material_id:'m',preferred_warehouse_id:'w',unit_cost:2,quantity_delivered:10}],movements:[{id:'a',project_id:'p',request_id:'r',material_id:'m',warehouse_id:'w',movement_type_code:'delivery',quantity:4,quantity_delta:-4,occurred_at:'2026-10-11T02:00:00Z'},{id:'b',project_id:'p',request_id:'r',material_id:'m',warehouse_id:'w',movement_type_code:'delivery',quantity:6,quantity_delta:-6,occurred_at:'2026-10-12T15:00:00Z'},{id:'c',project_id:'p',material_id:'m',movement_type_code:'reservation',quantity_delta:0,reserved_delta:10,quantity:10}]};
 const rows=buildReport('costs',source);assert.equal(rows.length,2);assert.deepEqual(rows.map(r=>r.amount),[8,12]);assert.equal(rows[0].day,'2026-10-10');
 assert.equal(buildReport('movements',source)[2].cells.Movimiento,'Reserva');
 assert.equal(buildReport('costs',{...source,items:[]})[0].amount,undefined);
 assert.equal(reportDay('2026-10-11'), '2026-10-11');
});
test('CSV conserva encabezados y neutraliza fórmulas de Excel',()=>{
 const csv=reportCsv([{id:'1',projectId:'p',day:'',cells:{Nombre:'=HYPERLINK("malicioso")',Detalle:'Uno, dos'}}]);
 assert.ok(csv.startsWith('\uFEFF'));assert.ok(csv.includes("'=HYPERLINK"));assert.ok(csv.includes('"Uno, dos"'));
});
