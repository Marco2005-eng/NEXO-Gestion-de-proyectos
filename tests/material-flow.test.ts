import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

type JsonObject = Record<string, unknown>;

test('materiales: entrega parcial, recepción, consumo, devolución, cancelación y kardex', { timeout: 120000 }, async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role;
      create schema auth; create schema storage;
      create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}'::jsonb);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated; grant execute on function auth.uid() to authenticated;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
      alter table storage.objects enable row level security;
      grant usage on schema storage to authenticated; grant select,insert on storage.objects to authenticated;
      create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
    `);
    const sql = (path: string) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
    for (const file of [
      'supabase/migrations/20260920000000_initial_schema.sql',
      'supabase/migrations/20261010000000_interface_workflows.sql',
      'supabase/migrations/20261010010000_team_assignments.sql',
      'supabase/migrations/20261010020000_notifications_roles.sql',
      'supabase/migrations/20261010030000_replace_roles.sql',
      'supabase/migrations/20261010040000_personal_profile.sql',
      'supabase/migrations/20261011000000_task_update_policy.sql',
      'supabase/migrations/20261011010000_platform_organizations.sql',
      'supabase/20_permisos_jefes_proyectos.sql',
      'supabase/20_permisos_jefes_proyectos.sql',
      'supabase/15_materiales_excel_solicitudes.sql',
    ]) await db.exec(sql(file));

    const admin = '11111111-1111-4111-8111-111111111111';
    const lead = '22222222-2222-4222-8222-222222222222';
    await db.query('insert into auth.users(id,email) values($1,$2),($3,$4)', [admin, 'admin@example.test', lead, 'lead@example.test']);
    await db.query("select private.bootstrap_organization('Uno','uno',$1)", [admin]);
    for (const file of ['supabase/21_inversion_materiales_presupuesto.sql', 'supabase/22_materiales_flujo_completo.sql', 'supabase/22_materiales_flujo_completo.sql']) {
      await db.exec(sql(file));
    }
    const org = (await db.query<{ id: string }>("select id from organizations where slug='uno'")).rows[0].id;
    const project = (await db.query<{ id: string }>("insert into projects(organization_id,code,name,budget) values($1,'P1','Red',1000) returning id", [org])).rows[0].id;
    await db.query("insert into organization_members(organization_id,user_id,status) values($1,$2,'active')", [org, lead]);
    const leadMember = (await db.query<{ id: string }>('select id from organization_members where user_id=$1', [lead])).rows[0].id;
    await db.query('insert into project_members(project_id,member_id,is_project_manager) values($1,$2,true)', [project, leadMember]);
    await db.query("insert into member_role_assignments(organization_id,member_id,role_id,scope_type,project_id) select $1,$2,id,'project',$3 from roles where organization_id=$1 and code='project_manager'", [org, leadMember, project]);

    const actor = async (user: string) => {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,false)", [user]);
      await db.exec('set role authenticated');
    };
    const command = async (name: string, payload: JsonObject) =>
      (await db.query<{ id: string }>('select nexo_material_command($1,$2::jsonb) id', [name, JSON.stringify(payload)])).rows[0].id;
    const flow = async (name: string, payload: JsonObject) =>
      (await db.query<{ value: JsonObject }>('select nexo_material_flow($1,$2::jsonb) value', [name, JSON.stringify(payload)])).rows[0].value;
    const scalar = async <T>(query: string, params: unknown[] = []) => Object.values((await db.query<Record<string, T>>(query, params)).rows[0])[0];
    const createRequest = async (material: string, warehouse: string, quantity: number, justification: string) => {
      await actor(lead);
      const id = await command('request.create', { project_id: project, justification, items: [{ material_id: material, warehouse_id: warehouse, quantity }] });
      await command('request.submit', { id });
      await actor(admin);
      await command('request.decide', { id, decision: 'approved' });
      await command('request.reserve', { id });
      return id;
    };
    const requestItem = async (requestId: string) =>
      (await db.query<{ id: string; material_id: string }>('select id, material_id from material_request_items where request_id=$1', [requestId])).rows[0].id;

    await actor(admin);
    await db.query('select nexo_import_materials($1::jsonb)', [JSON.stringify({
      project_id: project, mode: 'initial', file_digest: 'a'.repeat(64), file_name: 'inicial.xlsx',
      rows: [
        { sku: 'CAB', name: 'Cable', unit: 'metro', kind: 'consumable', quantity: 10, price: 10, minimum: 0 },
        { sku: 'TAL', name: 'Taladro', unit: 'unidad', kind: 'returnable', quantity: 2, price: 50, minimum: 0 },
      ],
    })]);
    const cab = (await db.query<{ id: string }>("select id from materials where sku='CAB'")).rows[0].id;
    const drill = (await db.query<{ id: string }>("select id from materials where sku='TAL'")).rows[0].id;
    const warehouse = (await db.query<{ id: string }>('select id from warehouses where project_id=$1', [project])).rows[0].id;

    // Consumo completo con entrega parcial y confirmación por código.
    const consumption = await createRequest(cab, warehouse, 3, 'Cableado del módulo A');
    const consumptionItem = await requestItem(consumption);
    const first = await flow('deliver', { request_id: consumption, items: [{ request_item_id: consumptionItem, quantity: 1 }] });
    assert.equal(first.status, 'partially_delivered');
    assert.match(String(first.code), /^[0-9]{6}$/);
    assert.equal(await scalar<string>('select status_code from material_requests where id=$1', [consumption]), 'partially_delivered');

    await actor(lead);
    await assert.rejects(flow('receive', { request_id: consumption, delivery_id: first.delivery_id, code: '000000' }), /Código de confirmación incorrecto/);
    const firstReception = await flow('receive', { request_id: consumption, delivery_id: first.delivery_id, code: first.code });
    assert.equal(firstReception.received, false);
    assert.equal(await scalar<string | null>('select received_at from material_requests where id=$1', [consumption]), null);

    await actor(admin);
    const second = await flow('deliver', { request_id: consumption });
    assert.equal(second.status, 'delivered');
    await actor(lead);
    const secondReception = await flow('receive', { request_id: consumption, delivery_id: second.delivery_id, code: second.code });
    assert.equal(secondReception.received, true);
    assert.notEqual(await scalar<string | null>('select received_at from material_requests where id=$1', [consumption]), null);

    const usage = await flow('usage', {
      request_id: consumption, summary: 'Se utilizó todo el cable en la instalación',
      items: [{ request_item_id: consumptionItem, quantity_used: 3, quantity_remaining: 0 }],
    });
    assert.equal(usage.status, 'usage_reported');
    const closed = await flow('close', { request_id: consumption });
    assert.equal(closed.status, 'closed');
    assert.equal(await scalar<string>('select on_hand::text from material_stock where material_id=$1 and warehouse_id=$2', [cab, warehouse]), '7.0000');
    const consumptionBalance = await scalar<JsonObject>('select to_jsonb(v) from material_request_item_balances v where request_item_id=$1', [consumptionItem]);
    assert.equal(Number(consumptionBalance.quantity_confirmed), 3);
    assert.equal(Number(consumptionBalance.quantity_used), 3);
    assert.equal(Number(consumptionBalance.quantity_pending_return), 0);

    // Devolución parcial y dañada.
    const returns = await createRequest(drill, warehouse, 2, 'Taladros para el frente de obra');
    const drillItem = await requestItem(returns);
    const delivery = await flow('deliver', { request_id: returns });
    await actor(lead);
    await flow('receive', { request_id: returns, delivery_id: delivery.delivery_id, code: delivery.code });

    await actor(admin);
    const goodReturn = await flow('return', {
      request_id: returns, notes: 'Equipo en buen estado',
      items: [{ request_item_id: drillItem, quantity: 1, condition: 'good' }],
    });
    assert.equal(goodReturn.status, 'delivered');
    const damagedReturn = await flow('return', {
      request_id: returns, notes: 'Equipo dañado en obra',
      items: [{ request_item_id: drillItem, quantity: 1, condition: 'damaged' }],
    });
    assert.equal(damagedReturn.status, 'returned');
    assert.equal(await scalar<string>('select on_hand::text from material_stock where material_id=$1 and warehouse_id=$2', [drill, warehouse]), '1.0000');
    const returnBalance = await scalar<JsonObject>('select to_jsonb(v) from material_request_item_balances v where request_item_id=$1', [drillItem]);
    assert.equal(Number(returnBalance.quantity_returned), 2);
    assert.equal(Number(returnBalance.quantity_returned_good), 1);
    assert.equal(Number(returnBalance.quantity_pending_return), 0);

    await actor(lead);
    const closedReturn = await flow('close', { request_id: returns });
    assert.equal(closedReturn.status, 'closed');

    // Cancelación con liberación de reserva.
    const cancellation = await createRequest(cab, warehouse, 5, 'Material que finalmente no se usará');
    await actor(admin);
    const cancelled = await flow('cancel', { request_id: cancellation, comment: 'El frente de trabajo fue reprogramado' });
    assert.equal(cancelled.status, 'cancelled');
    assert.equal(await scalar<string>('select quantity_reserved::text from material_request_items where request_id=$1', [cancellation]), '0.0000');
    assert.equal(await scalar<number>("select count(*)::int from stock_movements where request_id=$1 and movement_type_code='reservation_release'", [cancellation]), 1);

    // RLS: ya no se puede escribir el flujo directamente.
    await actor(lead);
    await assert.rejects(
      db.query('select confirmation_code_hash from material_deliveries where request_id=$1', [consumption]),
      /permission denied/i,
    );
    assert.equal(await scalar<boolean>('select requires_confirmation_code from material_deliveries where request_id=$1 limit 1', [consumption]), true);
    await assert.rejects(
      db.query("update material_requests set status_code='approved' where id=$1", [cancellation]),
      /permission denied|row-level security/i,
    );
    await assert.rejects(
      db.query("insert into stock_movements(organization_id,project_id,material_id,warehouse_id,movement_type_code,quantity,quantity_delta,balance_after,recorded_by,reference_id,reference_type) values($1,$2,$3,$4,'negative_adjustment',1,0,0,$5,$2,'test')", [org, project, cab, warehouse, admin]),
      /permission denied|row-level security/i,
    );

    const kardex = await scalar<{ total: number; rows: JsonObject[] }>('select nexo_material_kardex($1,$2) value', [project, cab]);
    assert.ok(kardex.total >= 4);
    assert.ok(kardex.rows.some((row) => row.movement_type_code === 'delivery'));
    assert.ok(kardex.rows.some((row) => row.movement_type_code === 'reservation_release'));
  } finally {
    await db.close();
  }
});
