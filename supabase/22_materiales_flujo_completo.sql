-- Nexo: flujo completo de materiales. Ejecutar después de 21_inversion_materiales_presupuesto.sql.
-- Cubre entregas parciales, confirmación de recepción con código, devoluciones,
-- reporte de consumo, cierre, cancelación, kardex y endurecimiento de escrituras.
begin;

-- -----------------------------------------------------------------------------
-- 1. Datos de recepción y control de entregas
-- -----------------------------------------------------------------------------
alter table public.material_requests
  add column if not exists received_at timestamptz,
  add column if not exists received_by_member_id uuid references public.organization_members(id) on delete set null,
  add column if not exists received_evidence_file_id uuid references public.files(id) on delete set null;

alter table public.material_deliveries
  add column if not exists confirmation_code_hash text,
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_by_member_id uuid references public.organization_members(id) on delete set null,
  add column if not exists reception_evidence_file_id uuid references public.files(id) on delete set null,
  add column if not exists requires_confirmation_code boolean generated always as (confirmation_code_hash is not null) stored;

alter table public.material_request_items
  drop constraint if exists material_request_items_delivered_within_approved;
alter table public.material_request_items
  add constraint material_request_items_delivered_within_approved
  check (quantity_delivered <= coalesce(quantity_approved, quantity_requested)) not valid;

create index if not exists material_deliveries_request_idx
  on public.material_deliveries(request_id, delivered_at desc, id);
create index if not exists material_delivery_items_request_item_idx
  on public.material_delivery_items(request_item_id);
create index if not exists material_returns_request_idx
  on public.material_returns(request_id, returned_at desc, id);
create index if not exists material_return_items_request_item_idx
  on public.material_return_items(request_item_id);
create index if not exists material_usage_report_items_request_item_idx
  on public.material_usage_report_items(request_item_id);
create index if not exists stock_movements_project_time_idx
  on public.stock_movements(project_id, occurred_at desc, id) where project_id is not null;

-- -----------------------------------------------------------------------------
-- 2. Vista de saldos por línea de solicitud
-- -----------------------------------------------------------------------------
create or replace view public.material_request_item_balances with (security_invoker = true) as
select
  i.id as request_item_id,
  i.request_id,
  r.project_id,
  i.material_id,
  m.sku,
  m.name as material_name,
  m.unit_of_measure,
  m.material_kind,
  m.requires_return,
  m.requires_usage_report,
  i.quantity_requested,
  coalesce(i.quantity_approved, 0) as quantity_approved,
  i.quantity_reserved,
  i.quantity_delivered,
  coalesce((
    select sum(di.quantity)
    from public.material_delivery_items di
    join public.material_deliveries d on d.id = di.delivery_id
    where di.request_item_id = i.id and d.confirmed_at is not null
  ), 0) as quantity_confirmed,
  coalesce((
    select sum(ri.quantity)
    from public.material_return_items ri
    where ri.request_item_id = i.id
  ), 0) as quantity_returned,
  coalesce((
    select sum(ri.quantity)
    from public.material_return_items ri
    where ri.request_item_id = i.id and ri.condition = 'good'
  ), 0) as quantity_returned_good,
  coalesce((
    select sum(ui.quantity_used)
    from public.material_usage_report_items ui
    join public.material_usage_reports u on u.id = ui.usage_report_id
    where ui.request_item_id = i.id and u.request_id = i.request_id
  ), 0) as quantity_used,
  coalesce((
    select sum(ui.quantity_remaining)
    from public.material_usage_report_items ui
    join public.material_usage_reports u on u.id = ui.usage_report_id
    where ui.request_item_id = i.id and u.request_id = i.request_id
  ), 0) as quantity_remaining,
  case when m.material_kind = 'returnable' then greatest(i.quantity_delivered - coalesce((
    select sum(ri.quantity)
    from public.material_return_items ri
    where ri.request_item_id = i.id
  ), 0), 0) else 0 end as quantity_pending_return,
  greatest(i.quantity_delivered - coalesce((
    select sum(di.quantity)
    from public.material_delivery_items di
    join public.material_deliveries d on d.id = di.delivery_id
    where di.request_item_id = i.id and d.confirmed_at is not null
  ), 0), 0) as quantity_pending_confirmation
from public.material_request_items i
join public.material_requests r on r.id = i.request_id
join public.materials m on m.id = i.material_id;

grant select on public.material_request_item_balances to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Contexto común y validación de archivos
-- -----------------------------------------------------------------------------
create or replace function private.nexo_material_request_for_update(p_request_id uuid)
returns public.material_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.material_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  if p_request_id is null then raise exception 'Solicitud no disponible.'; end if;
  select * into v_request
  from public.material_requests
  where id = p_request_id and deleted_at is null
  for update;
  if not found or not private.can_access_material_request(v_request.id) then
    raise exception 'Solicitud no disponible.';
  end if;
  return v_request;
end;
$$;
revoke all on function private.nexo_material_request_for_update(uuid) from public, anon;
grant execute on function private.nexo_material_request_for_update(uuid) to authenticated;

create or replace function private.nexo_validate_file(p_file_id uuid, p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_file_id is not null and not exists (
    select 1 from public.files
    where id = p_file_id and organization_id = p_organization_id and deleted_at is null
  ) then
    raise exception 'El archivo de evidencia no es válido.';
  end if;
end;
$$;
revoke all on function private.nexo_validate_file(uuid, uuid) from public, anon;
grant execute on function private.nexo_validate_file(uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Comandos del flujo
-- -----------------------------------------------------------------------------
create or replace function public.nexo_material_flow(p_command text, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_request public.material_requests%rowtype;
  v_project public.projects%rowtype;
  v_member uuid;
  v_item public.material_request_items%rowtype;
  v_delivery public.material_deliveries%rowtype;
  v_entry jsonb;
  v_items jsonb;
  v_qty numeric;
  v_used numeric;
  v_remaining numeric;
  v_warehouse uuid;
  v_id uuid;
  v_delivery_number text;
  v_code text;
  v_status text;
  v_count integer;
  v_pending numeric;
  v_sku text;
  v_kind text;
  v_condition text;
  v_file uuid;
  v_note text;
begin
  if v_user is null then raise exception 'Debes iniciar sesión.'; end if;
  if p_payload is null or p_command not in ('deliver','receive','return','usage','cancel','close') then
    raise exception 'Operación no disponible.';
  end if;

  v_request := private.nexo_material_request_for_update(nullif(p_payload->>'request_id','')::uuid);
  select * into v_project
  from public.projects
  where id = v_request.project_id and deleted_at is null;
  if not found then raise exception 'Proyecto no disponible.'; end if;

  v_member := private.current_member_id(v_request.organization_id);
  if v_member is null then raise exception 'No eres miembro activo de esta organización.'; end if;

  if p_command = 'deliver' then
    if not private.has_permission(v_request.organization_id, 'material.manage_stock', v_project.id, v_project.area_id) then
      raise exception 'No tienes permiso para gestionar existencias.';
    end if;
    if v_request.status_code not in ('reserved','partially_delivered') then
      raise exception 'Solo se puede entregar una solicitud reservada o con entrega parcial.';
    end if;

    select count(distinct preferred_warehouse_id) into v_count
    from public.material_request_items
    where request_id = v_request.id;
    select preferred_warehouse_id into v_warehouse
    from public.material_request_items
    where request_id = v_request.id
    limit 1;
    if v_count <> 1 or v_warehouse is null then
      raise exception 'Esta entrega admite un solo almacén. Divide la solicitud por almacén.';
    end if;

    if p_payload->'items' is null or jsonb_typeof(p_payload->'items') is null then
      select jsonb_agg(jsonb_build_object('request_item_id', id, 'quantity', quantity_reserved) order by material_id, id)
      into v_items
      from public.material_request_items
      where request_id = v_request.id and quantity_reserved > 0;
    else
      if jsonb_typeof(p_payload->'items') <> 'array' then
        raise exception 'El detalle de la entrega es inválido.';
      end if;
      v_items := p_payload->'items';
    end if;

    if v_items is null or jsonb_array_length(v_items) = 0 then
      raise exception 'No hay cantidades reservadas para entregar.';
    end if;
    if exists (
      select 1 from jsonb_array_elements(v_items) x
      group by x->>'request_item_id' having count(*) > 1
    ) then
      raise exception 'No repitas un material en la misma entrega.';
    end if;

    v_code := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    insert into public.material_deliveries(
      organization_id, request_id, warehouse_id, delivered_by_member_id,
      received_by_member_id, delivery_number, confirmation_code_hash, notes
    ) values (
      v_request.organization_id, v_request.id, v_warehouse, v_member,
      v_request.requested_by_member_id,
      'ENT-' || left(extensions.gen_random_uuid()::text, 8),
      encode(extensions.digest(v_code, 'sha256'), 'hex'),
      nullif(trim(p_payload->>'notes'), '')
    ) returning id, delivery_number into v_id, v_delivery_number;

    v_pending := 0;
    for v_entry in select * from jsonb_array_elements(v_items) loop
      v_qty := nullif(v_entry->>'quantity', '')::numeric;
      if v_qty is null or v_qty <= 0 then raise exception 'Cantidad de entrega inválida.'; end if;
      select * into v_item
      from public.material_request_items
      where id = nullif(v_entry->>'request_item_id','')::uuid and request_id = v_request.id
      for update;
      if not found then raise exception 'El material no pertenece a la solicitud.'; end if;
      if v_item.preferred_warehouse_id is distinct from v_warehouse then
        raise exception 'La entrega debe usar el almacén de la solicitud.';
      end if;
      if v_qty > v_item.quantity_reserved then
        select sku into v_sku from public.materials where id = v_item.material_id;
        raise exception 'La cantidad supera lo reservado para %.', coalesce(v_sku, 'el material');
      end if;

      insert into public.stock_movements(
        organization_id, material_id, warehouse_id, movement_type_code,
        quantity, quantity_delta, balance_after, reference_type, reference_id,
        project_id, request_id, recorded_by, reason
      ) values (
        v_request.organization_id, v_item.material_id, v_warehouse, 'delivery',
        v_qty, 0, 0, 'material_delivery', v_id,
        v_project.id, v_request.id, v_user, 'Entrega de materiales'
      );
      insert into public.material_delivery_items(delivery_id, request_item_id, material_id, quantity, condition_notes)
      values (v_id, v_item.id, v_item.material_id, v_qty, nullif(trim(v_entry->>'notes'), ''));
      update public.material_request_items
      set quantity_reserved = quantity_reserved - v_qty,
          quantity_delivered = quantity_delivered + v_qty,
          updated_at = now()
      where id = v_item.id;
    end loop;

    select coalesce(sum(quantity_reserved), 0) into v_pending
    from public.material_request_items where request_id = v_request.id;
    v_status := case when v_pending = 0 then 'delivered' else 'partially_delivered' end;
    update public.material_requests set status_code = v_status where id = v_request.id;

    return jsonb_build_object(
      'id', v_id, 'delivery_id', v_id, 'delivery_number', v_delivery_number,
      'code', v_code, 'status', v_status, 'pending_reserved', v_pending
    );

  elsif p_command = 'receive' then
    if v_request.requested_by_member_id <> v_member then
      raise exception 'Solo el solicitante puede confirmar la recepción.';
    end if;
    if v_request.status_code not in ('delivered','partially_delivered') then
      raise exception 'La solicitud no tiene entregas por confirmar.';
    end if;

    if nullif(p_payload->>'delivery_id','') is not null then
      select * into v_delivery
      from public.material_deliveries
      where id = (p_payload->>'delivery_id')::uuid and request_id = v_request.id
      for update;
    else
      select * into v_delivery
      from public.material_deliveries
      where request_id = v_request.id and confirmed_at is null
      order by delivered_at desc, id desc
      limit 1
      for update;
    end if;
    if not found then raise exception 'No hay entregas pendientes de confirmación.'; end if;
    if v_delivery.confirmed_at is not null then raise exception 'Esta entrega ya fue confirmada.'; end if;

    if v_delivery.confirmation_code_hash is not null then
      v_code := trim(coalesce(p_payload->>'code', ''));
      if v_code !~ '^[0-9]{6}$'
        or encode(extensions.digest(v_code, 'sha256'), 'hex') <> v_delivery.confirmation_code_hash then
        raise exception 'Código de confirmación incorrecto.';
      end if;
    end if;

    v_file := nullif(p_payload->>'evidence_file_id', '')::uuid;
    perform private.nexo_validate_file(v_file, v_request.organization_id);

    update public.material_deliveries
    set confirmed_at = now(), confirmed_by_member_id = v_member,
        reception_evidence_file_id = v_file
    where id = v_delivery.id;

    if v_request.status_code = 'delivered' and not exists (
      select 1 from public.material_deliveries
      where request_id = v_request.id and confirmed_at is null
    ) then
      update public.material_requests
      set received_at = now(), received_by_member_id = v_member,
          received_evidence_file_id = v_file
      where id = v_request.id;
    end if;

    return jsonb_build_object(
      'id', v_delivery.id, 'delivery_id', v_delivery.id,
      'status', v_request.status_code, 'received', v_request.status_code = 'delivered'
    );

  elsif p_command = 'return' then
    if not private.has_permission(v_request.organization_id, 'material.manage_stock', v_project.id, v_project.area_id) then
      raise exception 'No tienes permiso para recibir devoluciones.';
    end if;
    if v_request.status_code <> 'delivered' then
      raise exception 'Solo se pueden devolver materiales de una solicitud entregada.';
    end if;
    if v_request.received_at is null then
      raise exception 'Primero confirma la recepción de la entrega.';
    end if;
    if jsonb_typeof(p_payload->'items') is distinct from 'array' then
      raise exception 'Agrega los materiales a devolver.';
    end if;
    v_count := jsonb_array_length(p_payload->'items');
    if v_count not between 1 and 30 then raise exception 'Agrega entre 1 y 30 materiales.'; end if;
    if exists (
      select 1 from jsonb_array_elements(p_payload->'items') x
      group by x->>'request_item_id' having count(*) > 1
    ) then
      raise exception 'No repitas un material en la misma devolución.';
    end if;

    select count(distinct preferred_warehouse_id) into v_count
    from public.material_request_items
    where request_id = v_request.id;
    select preferred_warehouse_id into v_warehouse
    from public.material_request_items
    where request_id = v_request.id
    limit 1;
    if v_count <> 1 or v_warehouse is null then
      raise exception 'La devolución debe usar el almacén de la solicitud.';
    end if;
    if not exists (
      select 1
      from public.material_request_items i
      join public.materials m on m.id = i.material_id
      where i.request_id = v_request.id and m.material_kind = 'returnable' and i.quantity_delivered > 0
    ) then
      raise exception 'La solicitud no tiene materiales devolvibles.';
    end if;

    v_file := nullif(p_payload->>'evidence_file_id', '')::uuid;
    perform private.nexo_validate_file(v_file, v_request.organization_id);
    insert into public.material_returns(
      organization_id, request_id, warehouse_id, returned_by_member_id,
      received_by_member_id, notes, evidence_file_id
    ) values (
      v_request.organization_id, v_request.id, v_warehouse,
      v_request.requested_by_member_id, v_member,
      nullif(trim(p_payload->>'notes'), ''), v_file
    ) returning id into v_id;

    for v_entry in select * from jsonb_array_elements(p_payload->'items') loop
      v_qty := nullif(v_entry->>'quantity', '')::numeric;
      if v_qty is null or v_qty <= 0 then raise exception 'Cantidad de devolución inválida.'; end if;
      v_condition := coalesce(nullif(trim(v_entry->>'condition'), ''), 'good');
      if v_condition not in ('good','damaged','lost','maintenance_required') then
        raise exception 'Condición de devolución inválida.';
      end if;
      select * into v_item
      from public.material_request_items
      where id = nullif(v_entry->>'request_item_id','')::uuid and request_id = v_request.id
      for update;
      if not found then raise exception 'El material no pertenece a la solicitud.'; end if;
      select material_kind, sku into v_kind, v_sku
      from public.materials where id = v_item.material_id;
      if v_kind <> 'returnable' then
        raise exception 'Solo los materiales devolvibles pueden registrarse como devolución.';
      end if;
      if v_qty + coalesce((
        select sum(ri.quantity) from public.material_return_items ri
        where ri.request_item_id = v_item.id
      ), 0) > v_item.quantity_delivered then
        raise exception 'La devolución supera lo entregado para %.', v_sku;
      end if;

      insert into public.material_return_items(return_id, request_item_id, material_id, quantity, condition, notes)
      values (v_id, v_item.id, v_item.material_id, v_qty, v_condition, nullif(trim(v_entry->>'notes'), ''));

      if v_condition = 'good' then
        insert into public.stock_movements(
          organization_id, material_id, warehouse_id, movement_type_code,
          quantity, quantity_delta, balance_after, reference_type, reference_id,
          project_id, request_id, recorded_by, reason
        ) values (
          v_request.organization_id, v_item.material_id, v_warehouse, 'return',
          v_qty, 0, 0, 'material_return', v_id,
          v_project.id, v_request.id, v_user, 'Devolución de materiales'
        );
      end if;
    end loop;

    select count(*) into v_count
    from public.material_request_items i
    join public.materials m on m.id = i.material_id
    where i.request_id = v_request.id
      and m.material_kind = 'returnable'
      and i.quantity_delivered > coalesce((
        select sum(ri.quantity) from public.material_return_items ri
        where ri.request_item_id = i.id
      ), 0);
    if v_count = 0 then
      v_status := 'returned';
      update public.material_requests set status_code = v_status where id = v_request.id;
    else
      v_status := v_request.status_code;
    end if;

    return jsonb_build_object('id', v_id, 'status', v_status);

  elsif p_command = 'usage' then
    if v_request.requested_by_member_id <> v_member
      and not private.has_permission(v_request.organization_id, 'material.manage_stock', v_project.id, v_project.area_id) then
      raise exception 'Solo el solicitante o el gestor de almacén puede reportar el consumo.';
    end if;
    if v_request.status_code <> 'delivered' then
      raise exception 'Solo se puede reportar el consumo de una solicitud entregada.';
    end if;
    if v_request.received_at is null then
      raise exception 'Primero confirma la recepción de la entrega.';
    end if;
    if exists (select 1 from public.material_usage_reports where request_id = v_request.id) then
      raise exception 'La solicitud ya tiene un reporte de consumo.';
    end if;
    v_note := nullif(trim(p_payload->>'summary'), '');
    if v_note is null or length(v_note) not between 5 and 2000 then
      raise exception 'Ingresa un resumen del consumo.';
    end if;
    if jsonb_typeof(p_payload->'items') is distinct from 'array' then
      raise exception 'Agrega el detalle del consumo.';
    end if;
    v_count := jsonb_array_length(p_payload->'items');
    if v_count not between 1 and 30 then raise exception 'Agrega entre 1 y 30 materiales.'; end if;
    if exists (
      select 1 from jsonb_array_elements(p_payload->'items') x
      group by x->>'request_item_id' having count(*) > 1
    ) then
      raise exception 'No repitas un material en el reporte.';
    end if;

    v_file := nullif(p_payload->>'evidence_file_id', '')::uuid;
    perform private.nexo_validate_file(v_file, v_request.organization_id);
    insert into public.material_usage_reports(
      organization_id, request_id, reported_by_member_id, summary, evidence_file_id
    ) values (
      v_request.organization_id, v_request.id, v_member, v_note, v_file
    ) returning id into v_id;

    for v_entry in select * from jsonb_array_elements(p_payload->'items') loop
      v_used := coalesce(nullif(v_entry->>'quantity_used', '')::numeric, 0);
      v_remaining := coalesce(nullif(v_entry->>'quantity_remaining', '')::numeric, 0);
      if v_used < 0 or v_remaining < 0 then raise exception 'Las cantidades no pueden ser negativas.'; end if;
      select * into v_item
      from public.material_request_items
      where id = nullif(v_entry->>'request_item_id','')::uuid and request_id = v_request.id
      for update;
      if not found then raise exception 'El material no pertenece a la solicitud.'; end if;
      if v_used + v_remaining > v_item.quantity_delivered - coalesce((
        select sum(ri.quantity) from public.material_return_items ri
        where ri.request_item_id = v_item.id
      ), 0) then
        raise exception 'El consumo supera lo entregado para el material.';
      end if;
      insert into public.material_usage_report_items(usage_report_id, request_item_id, quantity_used, quantity_remaining, notes)
      values (v_id, v_item.id, v_used, v_remaining, nullif(trim(v_entry->>'notes'), ''));
    end loop;

    v_status := 'usage_reported';
    update public.material_requests set status_code = v_status where id = v_request.id;
    return jsonb_build_object('id', v_id, 'status', v_status);

  elsif p_command = 'cancel' then
    v_note := nullif(trim(p_payload->>'comment'), '');
    if v_note is null then raise exception 'Indica el motivo de la cancelación.'; end if;

    if v_request.status_code in ('draft','needs_changes') then
      if v_request.requested_by_member_id <> v_member then
        raise exception 'Solo el solicitante puede cancelar este borrador.';
      end if;
    elsif v_request.status_code = 'pending' then
      if v_request.requested_by_member_id <> v_member then
        raise exception 'Solo el solicitante puede cancelar una solicitud pendiente.';
      end if;
      update public.approval_instances
      set status_code = 'cancelled', completed_at = now()
      where subject_type = 'material_request' and subject_id = v_request.id
        and status_code in ('pending','needs_changes');
      update public.approval_instance_steps s
      set status_code = 'cancelled', decided_by_member_id = v_member,
          decision_comment = v_note, decided_at = now()
      from public.approval_instances i
      where i.id = s.approval_instance_id
        and i.subject_type = 'material_request' and i.subject_id = v_request.id
        and s.status_code in ('pending','needs_changes');
    elsif v_request.status_code in ('approved','reserved','partially_delivered') then
      if not private.has_permission(v_request.organization_id, 'material.manage_stock', v_project.id, v_project.area_id)
        and not private.has_permission(v_request.organization_id, 'material.approve', v_project.id, v_project.area_id) then
        raise exception 'No tienes permiso para cancelar esta solicitud.';
      end if;
      if v_request.status_code in ('reserved','partially_delivered') then
        for v_item in
          select * from public.material_request_items
          where request_id = v_request.id and quantity_reserved > 0
          order by material_id, id
          for update
        loop
          insert into public.stock_movements(
            organization_id, material_id, warehouse_id, movement_type_code,
            quantity, quantity_delta, balance_after, reference_type, reference_id,
            project_id, request_id, recorded_by, reason
          ) values (
            v_request.organization_id, v_item.material_id, v_item.preferred_warehouse_id,
            'reservation_release', v_item.quantity_reserved, 0, 0,
            'material_request', v_request.id,
            v_project.id, v_request.id, v_user, 'Cancelación de solicitud'
          );
          update public.material_request_items
          set quantity_reserved = 0, updated_at = now()
          where id = v_item.id;
        end loop;
      end if;
    else
      raise exception 'No se puede cancelar una solicitud en estado %.', v_request.status_code;
    end if;

    v_status := 'cancelled';
    update public.material_requests
    set status_code = v_status, cancelled_at = now()
    where id = v_request.id;
    update public.material_request_status_history
    set comment = v_note
    where request_id = v_request.id and changed_at = now() and to_status = v_status;
    return jsonb_build_object('id', v_request.id, 'status', v_status);

  elsif p_command = 'close' then
    if v_request.status_code not in ('usage_reported','returned') then
      raise exception 'Solo se puede cerrar una solicitud con consumo reportado o devuelta.';
    end if;
    if v_request.requested_by_member_id <> v_member
      and not private.has_permission(v_request.organization_id, 'material.manage_stock', v_project.id, v_project.area_id)
      and not private.has_permission(v_request.organization_id, 'material.approve', v_project.id, v_project.area_id) then
      raise exception 'No tienes permiso para cerrar esta solicitud.';
    end if;
    v_status := 'closed';
    update public.material_requests
    set status_code = v_status, closed_at = now()
    where id = v_request.id;
    return jsonb_build_object('id', v_request.id, 'status', v_status);
  end if;

  raise exception 'Operación no disponible.';
end;
$$;
revoke all on function public.nexo_material_flow(text, jsonb) from public, anon;
grant execute on function public.nexo_material_flow(text, jsonb) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Kardex del proyecto
-- -----------------------------------------------------------------------------
create or replace function public.nexo_material_kardex(
  p_project_id uuid,
  p_material_id uuid default null,
  p_type text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project public.projects%rowtype;
  v_limit integer := coalesce(p_limit, 50);
  v_offset integer := coalesce(p_offset, 0);
  v_type text := nullif(trim(coalesce(p_type, '')), '');
  v_total integer;
  v_rows jsonb;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  select * into v_project from public.projects where id = p_project_id and deleted_at is null;
  if not found or not private.can_access_project(p_project_id) then
    raise exception 'Proyecto no disponible.';
  end if;
  if not (
    private.has_permission(v_project.organization_id, 'material.view', p_project_id, v_project.area_id)
    or private.has_permission(v_project.organization_id, 'material.manage_stock', p_project_id, v_project.area_id)
    or private.has_permission(v_project.organization_id, 'material.approve', p_project_id, v_project.area_id)
    or private.has_permission(v_project.organization_id, 'report.view', p_project_id, v_project.area_id)
    or private.has_permission(v_project.organization_id, 'project.manage', p_project_id, v_project.area_id)
  ) then
    raise exception 'No puedes consultar el kardex de este proyecto.';
  end if;
  if v_limit not between 1 and 200 then raise exception 'El límite debe estar entre 1 y 200.'; end if;
  if v_offset < 0 then raise exception 'El desplazamiento no puede ser negativo.'; end if;

  select count(*) into v_total
  from public.stock_movements s
  where s.project_id = p_project_id
    and (p_material_id is null or s.material_id = p_material_id)
    and (v_type is null or s.movement_type_code = v_type)
    and (p_from is null or s.occurred_at >= p_from)
    and (p_to is null or s.occurred_at <= p_to);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.occurred_at desc, x.id desc), '[]'::jsonb)
  into v_rows
  from (
    select
      s.id,
      s.occurred_at,
      s.movement_type_code,
      t.name as movement_type_name,
      s.material_id,
      m.sku,
      m.name as material_name,
      m.unit_of_measure,
      s.warehouse_id,
      w.name as warehouse_name,
      s.quantity,
      s.quantity_delta,
      s.balance_after,
      s.reserved_delta,
      s.reserved_balance_after,
      s.reference_type,
      s.reference_id,
      s.request_id,
      r.request_number,
      s.reason,
      s.recorded_by,
      coalesce(
        nullif(trim(p.display_name), ''),
        nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
        'Sistema'
      ) as recorded_by_name
    from public.stock_movements s
    join public.materials m on m.id = s.material_id
    join public.warehouses w on w.id = s.warehouse_id
    join public.stock_movement_types t on t.code = s.movement_type_code
    left join public.material_requests r on r.id = s.request_id
    left join public.profiles p on p.id = s.recorded_by
    where s.project_id = p_project_id
      and (p_material_id is null or s.material_id = p_material_id)
      and (v_type is null or s.movement_type_code = v_type)
      and (p_from is null or s.occurred_at >= p_from)
      and (p_to is null or s.occurred_at <= p_to)
    order by s.occurred_at desc, s.id desc
    limit v_limit offset v_offset
  ) x;

  return jsonb_build_object('total', v_total, 'limit', v_limit, 'offset', v_offset, 'rows', v_rows);
end;
$$;
revoke all on function public.nexo_material_kardex(uuid, uuid, text, timestamptz, timestamptz, integer, integer) from public, anon;
grant execute on function public.nexo_material_kardex(uuid, uuid, text, timestamptz, timestamptz, integer, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Endurecimiento: las escrituras del flujo solo pasan por RPC
-- -----------------------------------------------------------------------------
drop policy if exists material_requests_insert on public.material_requests;
drop policy if exists material_requests_update on public.material_requests;
drop policy if exists material_request_items_manage on public.material_request_items;
drop policy if exists stock_movements_insert on public.stock_movements;
drop policy if exists deliveries_insert on public.material_deliveries;
drop policy if exists delivery_items_insert on public.material_delivery_items;
drop policy if exists usage_reports_insert on public.material_usage_reports;
drop policy if exists usage_report_items_access on public.material_usage_report_items;
drop policy if exists returns_insert on public.material_returns;
drop policy if exists return_items_access on public.material_return_items;

-- Conserva la lectura de las líneas de consumo y devolución sin permitir escrituras.
drop policy if exists usage_report_items_select on public.material_usage_report_items;
drop policy if exists return_items_select on public.material_return_items;
create policy usage_report_items_select on public.material_usage_report_items for select to authenticated
  using (exists (
    select 1 from public.material_usage_reports u
    where u.id = usage_report_id and private.can_access_material_request(u.request_id)
  ));
create policy return_items_select on public.material_return_items for select to authenticated
  using (exists (
    select 1 from public.material_returns r
    where r.id = return_id and private.can_access_material_request(r.request_id)
  ));

revoke insert, update on public.material_requests from authenticated;
revoke insert, update, delete on public.material_request_items from authenticated;
revoke insert on public.stock_movements from authenticated;
revoke insert on public.material_deliveries, public.material_delivery_items from authenticated;
revoke insert, update on public.material_usage_reports from authenticated;
revoke insert, update, delete on public.material_usage_report_items from authenticated;
revoke insert on public.material_returns, public.material_return_items from authenticated;
revoke insert, update, delete on public.material_returns from authenticated;
revoke insert, update, delete on public.material_return_items from authenticated;

-- El hash del código de confirmación no se expone por PostgREST.
-- La vista de la app usa solo estas columnas y el indicador generado.
revoke select on public.material_deliveries from authenticated;
grant select (
  id, organization_id, request_id, warehouse_id, delivered_by_member_id,
  received_by_member_id, delivery_number, delivered_at, notes, evidence_file_id,
  created_at, confirmed_at, confirmed_by_member_id, reception_evidence_file_id,
  requires_confirmation_code
) on public.material_deliveries to authenticated;

commit;
