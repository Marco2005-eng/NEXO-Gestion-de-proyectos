-- Nexo: operaciones transaccionales para las interfaces de solicitudes.
-- Aplicar después del esquema inicial. No elimina datos ni cambia roles.
begin;

create or replace function public.nexo_material_command(p_command text, p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_member uuid;
  v_request public.material_requests%rowtype;
  v_project public.projects%rowtype;
  v_item record;
  v_entry jsonb;
  v_id uuid;
  v_instance uuid;
  v_flow uuid;
  v_step public.approval_flow_steps%rowtype;
  v_decision text;
  v_warehouse uuid;
  v_delivery uuid;
  v_qty numeric;
  v_count integer := 0;
begin
  if v_user is null then raise exception 'Debes iniciar sesión.'; end if;
  if p_command = 'request.create' then
    select * into v_project from public.projects where id = (p_payload->>'project_id')::uuid and deleted_at is null;
    if not found or not private.can_access_project(v_project.id) or not private.has_permission(v_project.organization_id, 'material.request', v_project.id, v_project.area_id) then
      raise exception 'No tienes permiso para solicitar en este proyecto.';
    end if;
    v_member := private.current_member_id(v_project.organization_id);
    if nullif(trim(p_payload->>'justification'), '') is null then raise exception 'Ingresa una justificación.'; end if;
    if jsonb_typeof(p_payload->'items') is distinct from 'array' then raise exception 'Agrega materiales.'; end if;
    if jsonb_array_length(p_payload->'items') not between 1 and 30 then raise exception 'Agrega entre 1 y 30 materiales.'; end if;
    if exists (select 1 from jsonb_array_elements(p_payload->'items') x group by x->>'material_id', x->>'warehouse_id' having count(*) > 1) then raise exception 'No repitas un material y almacén.'; end if;
    insert into public.material_requests(organization_id, request_number, project_id, requested_by_member_id,
      justification, priority_code, needed_at, created_by)
    values (v_project.organization_id, 'SOL-' || to_char(now(), 'YYYYMMDD') || '-' || left(extensions.gen_random_uuid()::text, 8),
      v_project.id, v_member, trim(p_payload->>'justification'), coalesce(nullif(p_payload->>'priority_code',''),'medium'),
      nullif(p_payload->>'needed_at','')::timestamptz, v_user)
    returning id into v_id;
    for v_entry in select * from jsonb_array_elements(p_payload->'items') loop
      v_qty := (v_entry->>'quantity')::numeric;
      if v_qty is null or v_qty <= 0 or v_qty > 1000000 then raise exception 'Cantidad inválida.'; end if;
      if not exists (select 1 from public.materials where id = (v_entry->>'material_id')::uuid and organization_id = v_project.organization_id and deleted_at is null and is_active)
        or not exists (select 1 from public.warehouses where id = (v_entry->>'warehouse_id')::uuid and organization_id = v_project.organization_id and is_active) then raise exception 'Material o almacén inválido.'; end if;
      insert into public.material_request_items(request_id, material_id, preferred_warehouse_id, quantity_requested, unit_cost)
      select v_id, id, (v_entry->>'warehouse_id')::uuid, v_qty, coalesce(standard_cost,0)
      from public.materials where id = (v_entry->>'material_id')::uuid;
    end loop;
    update public.material_requests set estimated_total = (select sum(quantity_requested * unit_cost) from public.material_request_items where request_id = v_id) where id = v_id;
    return v_id;
  end if;

  select * into v_request from public.material_requests where id = (p_payload->>'id')::uuid and deleted_at is null for update;
  if not found or not private.can_access_material_request(v_request.id) then raise exception 'Solicitud no disponible.'; end if;
  select * into v_project from public.projects where id = v_request.project_id and deleted_at is null;
  if not found then raise exception 'Proyecto no disponible.'; end if;
  v_member := private.current_member_id(v_request.organization_id);
  if v_member is null then raise exception 'No eres miembro activo de esta organización.'; end if;

  if p_command = 'request.submit' then
    if v_request.requested_by_member_id <> v_member or not private.has_permission(v_request.organization_id, 'material.request', v_project.id, v_project.area_id) then raise exception 'Solo el solicitante autorizado puede enviar el borrador.'; end if;
    if v_request.status_code not in ('draft','needs_changes') then raise exception 'La solicitud ya fue enviada.'; end if;
    if not exists (select 1 from public.material_request_items where request_id = v_request.id) then raise exception 'Agrega materiales antes de enviar.'; end if;
    select id into v_flow from public.approval_flows where organization_id = v_request.organization_id and subject_type = 'material_request' and is_active order by created_at limit 1;
    if v_flow is null then raise exception 'Configura primero un flujo de aprobación de materiales.'; end if;
    select count(*) into v_count from public.approval_flow_steps where flow_id = v_flow;
    select * into v_step from public.approval_flow_steps where flow_id = v_flow order by step_order limit 1;
    if v_count <> 1 or v_step.minimum_approvals <> 1 or v_step.approver_type not in ('role','member') then raise exception 'Esta versión admite un paso de aprobación por rol o miembro.'; end if;
    insert into public.approval_instances(organization_id, flow_id, subject_type, subject_id, project_id, requested_by_member_id)
    values (v_request.organization_id,v_flow,'material_request',v_request.id,v_project.id,v_member) returning id into v_instance;
    insert into public.approval_instance_steps(approval_instance_id, flow_step_id, step_order, assigned_role_id, assigned_member_id)
    values (v_instance,v_step.id,v_step.step_order,v_step.role_id,v_step.member_id);
    update public.material_requests set status_code = 'pending', submitted_at = now() where id = v_request.id;

  elsif p_command = 'request.decide' then
    if v_request.status_code <> 'pending' then raise exception 'La solicitud ya no está pendiente.'; end if;
    if v_request.requested_by_member_id = v_member then raise exception 'No puedes decidir tu propia solicitud.'; end if;
    if not private.has_permission(v_request.organization_id,'material.approve',v_project.id,v_project.area_id) then raise exception 'No tienes permiso para aprobar materiales.'; end if;
    select id into v_instance from public.approval_instances where subject_id = v_request.id and subject_type = 'material_request' and status_code = 'pending' order by created_at desc limit 1 for update;
    if v_instance is null then raise exception 'No hay una aprobación pendiente asociada.'; end if;
    if not private.has_permission(v_request.organization_id,'approval.manage',v_project.id,v_project.area_id) and not exists (
      select 1 from public.approval_instance_steps s
      where s.approval_instance_id = v_instance and s.status_code = 'pending' and (
        s.assigned_member_id = v_member or exists (
          select 1 from public.member_role_assignments a join public.roles r on r.id = a.role_id
          where a.member_id = v_member and a.role_id = s.assigned_role_id and r.is_active
            and a.valid_from <= now() and (a.valid_until is null or a.valid_until > now())
            and (a.scope_type='organization' or (a.scope_type='project' and a.project_id=v_project.id) or (a.scope_type='area' and a.area_id=v_project.area_id))
        )
      )
    ) then raise exception 'La aprobación está asignada a otro rol o miembro.'; end if;
    v_decision := p_payload->>'decision';
    if v_decision is null or v_decision not in ('approved','rejected','needs_changes') then raise exception 'Decisión inválida.'; end if;
    if v_decision <> 'approved' and nullif(trim(p_payload->>'comment'),'') is null then raise exception 'Ingresa el motivo de la decisión.'; end if;
    update public.approval_instance_steps set status_code = v_decision, decided_by_member_id = v_member, decision_comment = nullif(trim(p_payload->>'comment'),''), decided_at = now() where approval_instance_id = v_instance and status_code = 'pending';
    update public.approval_instances set status_code = v_decision, completed_at = now() where id = v_instance;
    if v_decision='approved' then update public.material_request_items set quantity_approved = quantity_requested where request_id = v_request.id; end if;
    update public.material_requests set status_code = v_decision where id = v_request.id;
    update public.material_request_status_history set comment = nullif(trim(p_payload->>'comment'),'') where request_id = v_request.id and changed_at = now() and to_status = v_decision;

  elsif p_command in ('request.reserve','request.deliver') then
    if not private.has_permission(v_request.organization_id,'material.manage_stock',v_project.id,v_project.area_id) then raise exception 'No tienes permiso para gestionar existencias.'; end if;
    if p_command='request.reserve' and v_request.status_code <> 'approved' then raise exception 'Solo se puede reservar una solicitud aprobada.'; end if;
    if p_command='request.deliver' and v_request.status_code <> 'reserved' then raise exception 'Solo se puede entregar una solicitud reservada.'; end if;
    if p_command='request.deliver' then
      select count(distinct preferred_warehouse_id) into v_count from public.material_request_items where request_id = v_request.id;
      if v_count <> 1 then raise exception 'Esta entrega admite un solo almacén. Divide la solicitud por almacén.'; end if;
      select preferred_warehouse_id into v_warehouse from public.material_request_items where request_id = v_request.id limit 1;
      insert into public.material_deliveries(organization_id, request_id, warehouse_id, delivered_by_member_id, received_by_member_id, delivery_number)
      values (v_request.organization_id,v_request.id,v_warehouse,v_member,v_request.requested_by_member_id,'ENT-' || left(extensions.gen_random_uuid()::text,8)) returning id into v_delivery;
    end if;
    v_count := 0;
    for v_item in select * from public.material_request_items where request_id = v_request.id order by material_id, preferred_warehouse_id for update loop
      v_qty := case when p_command='request.reserve' then v_item.quantity_approved else v_item.quantity_reserved end;
      if v_qty is null or v_qty <= 0 or v_item.preferred_warehouse_id is null then raise exception 'Revisa las cantidades aprobadas y el almacén de cada material.'; end if;
      insert into public.stock_movements(organization_id,material_id,warehouse_id,movement_type_code,quantity,quantity_delta,balance_after,project_id,request_id,recorded_by,reason)
      values (v_request.organization_id,v_item.material_id,v_item.preferred_warehouse_id,case when p_command='request.reserve' then 'reservation' else 'delivery' end,v_qty,0,0,v_project.id,v_request.id,v_user,'Operación desde Nexo');
      if p_command='request.reserve' then
        update public.material_request_items set quantity_reserved = v_qty where id = v_item.id;
      else
        insert into public.material_delivery_items(delivery_id,request_item_id,material_id,quantity) values(v_delivery,v_item.id,v_item.material_id,v_qty);
        update public.material_request_items set quantity_reserved = 0, quantity_delivered = quantity_delivered + v_qty where id = v_item.id;
      end if;
      v_count := v_count + 1;
    end loop;
    if v_count = 0 then raise exception 'La solicitud no tiene materiales.'; end if;
    update public.material_requests set status_code = case when p_command='request.reserve' then 'reserved' else 'delivered' end where id = v_request.id;
  else
    raise exception 'Operación no disponible.';
  end if;
  return v_request.id;
end;
$$;

revoke all on function public.nexo_material_command(text,jsonb) from public, anon;
grant execute on function public.nexo_material_command(text,jsonb) to authenticated;
commit;
