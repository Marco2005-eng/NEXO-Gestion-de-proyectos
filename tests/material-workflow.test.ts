import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateTransition, transitions, type RequestStatus } from '../src/features/materials/domain/request-workflow';
import { availableStock, validateReservation } from '../src/features/materials/domain/inventory';
test('recorrido hasta consumo y cierre', () => {
  const path: RequestStatus[] = ['draft','pending','approved','reserved','partially_delivered','delivered','usage_reported','closed'];
  for (let i=1;i<path.length;i++) validateTransition({from:path[i-1],to:path[i],actorMemberId:'a',requesterMemberId:'b'});
});
test('impide decisiones propias y saltos de estados', () => {
  for (const to of ['approved','rejected','needs_changes'] as const) assert.throws(() => validateTransition({from:'pending',to,actorMemberId:'a',requesterMemberId:'a',comment:'Motivo'}));
  for (const from of ['draft','closed','rejected','cancelled'] as const) assert.throws(() => validateTransition({from,to:'delivered',actorMemberId:'a',requesterMemberId:'b'}));
});
test('corrección requiere comentario', () => {
  assert.throws(() => validateTransition({from:'pending',to:'needs_changes',actorMemberId:'a',requesterMemberId:'b',comment:' '}));
  validateTransition({from:'pending',to:'needs_changes',actorMemberId:'a',requesterMemberId:'b',comment:'Completar sustento'});
});
test('reservas respetan saldo y cantidades válidas', () => {
  assert.equal(availableStock(10,4),6); validateReservation(6,10,4);
  for (const quantity of [7,0,-1,NaN,Infinity]) assert.throws(() => validateReservation(quantity,10,4));
  assert.throws(() => availableStock(5,6));
});
test('estados de dominio coinciden con las transiciones SQL', () => {
  const sql = readFileSync(new URL('../supabase/migrations/20260920000000_initial_schema.sql', import.meta.url), 'utf8');
  const section = sql.split('insert into public.material_request_status_transitions')[1].split(';')[0];
  const databasePairs = [...section.matchAll(/\('([^']+)', '([^']+)', (?:true|false)\)/g)].map(m => `${m[1]}:${m[2]}`).sort();
  const domainPairs = Object.entries(transitions).flatMap(([from, targets]) => targets.map(to => `${from}:${to}`)).sort();
  assert.deepEqual(domainPairs, databasePairs);
});
