-- Nexo: aplicar después de 14_avances_equipo_revision.sql. Conserva existencias.
begin;
alter table public.warehouses add column if not exists project_id uuid references public.projects(id) on delete restrict;
alter table public.material_stock add column if not exists unit_cost numeric(18,4) check(unit_cost>=0);
alter table public.material_requests add column if not exists received_at timestamptz;
alter table public.material_requests add column if not exists received_by_member_id uuid references public.organization_members(id);

-- Protege también los movimientos insertados directamente mediante la API.
create or replace function private.check_material_warehouse_project() returns trigger language plpgsql security definer set search_path='' as $$
declare v_project uuid;v_request_project uuid;
begin
 select project_id into v_project from public.warehouses where id=new.warehouse_id;
 if v_project is not null and new.project_id is distinct from v_project then raise exception 'El movimiento debe pertenecer al proyecto de su almacén.';end if;
 if new.request_id is not null then
 select project_id into v_request_project from public.material_requests where id=new.request_id;
 if new.project_id is distinct from v_request_project then raise exception 'El movimiento debe pertenecer al proyecto de su solicitud.';end if;
 end if;
 return new;
end;$$;
drop trigger if exists check_material_warehouse_project on public.stock_movements;
create trigger check_material_warehouse_project before insert on public.stock_movements for each row execute function private.check_material_warehouse_project();

create table if not exists public.material_import_batches(
 id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 project_id uuid not null references public.projects(id),warehouse_id uuid not null references public.warehouses(id),
 file_name text not null,file_digest text not null,mode text not null check(mode in ('initial','purchase')),
 row_count integer not null,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),
 unique(organization_id,warehouse_id,file_digest)
);
alter table public.material_import_batches enable row level security;
drop policy if exists material_import_batches_select on public.material_import_batches;
create policy material_import_batches_select on public.material_import_batches for select to authenticated using(
 private.can_access_project(project_id) and (private.has_permission(organization_id,'material.manage_stock',project_id) or private.has_permission(organization_id,'audit.view',project_id))
);
grant select on public.material_import_batches to authenticated;

-- Los permisos del jefe conservan el alcance de la asignación (su proyecto).
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where r.code='project_manager'
 and p.code in ('material.manage_catalog','material.manage_stock','material.approve') on conflict do nothing;
create or replace function private.project_material_permissions() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.code='project_manager' then
 insert into public.role_permissions(role_id,permission_id) select new.id,id from public.permissions
 where code in ('material.manage_catalog','material.manage_stock','material.approve') on conflict do nothing;
 end if;return new;
end;$$;
drop trigger if exists project_material_permissions on public.roles;
create trigger project_material_permissions after insert on public.roles for each row execute function private.project_material_permissions();

create or replace function private.can_view_material_org(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_permission(p_org,'material.view') or exists(select 1 from public.projects p where p.organization_id=p_org and p.deleted_at is null and private.can_access_project(p.id) and private.has_permission(p_org,'material.view',p.id,p.area_id));
$$;
revoke all on function private.can_view_material_org(uuid) from public,anon;
grant execute on function private.can_view_material_org(uuid) to authenticated;
drop policy if exists materials_select on public.materials;
create policy materials_select on public.materials for select to authenticated using(private.can_view_material_org(organization_id) and deleted_at is null);
drop policy if exists warehouses_select on public.warehouses;
create policy warehouses_select on public.warehouses for select to authenticated using(
 (project_id is null and private.can_view_material_org(organization_id)) or
 (project_id is not null and private.can_access_project(project_id) and private.has_permission(organization_id,'material.view',project_id))
);
drop policy if exists material_stock_select on public.material_stock;
create policy material_stock_select on public.material_stock for select to authenticated using(
 exists(select 1 from public.warehouses w where w.id=warehouse_id)
);
create or replace view public.inventory_availability with(security_invoker=true) as
 select m.id material_id,m.organization_id,m.sku,m.name,m.unit_of_measure,m.minimum_stock,w.id warehouse_id,w.name warehouse_name,
 s.on_hand,s.reserved,s.on_hand-s.reserved available,
 case when s.on_hand-s.reserved<=0 then 'out_of_stock' when s.on_hand-s.reserved<=m.minimum_stock then 'low_stock' else 'available' end availability_status,
 s.updated_at,coalesce(s.unit_cost,m.standard_cost,0) unit_cost,w.project_id warehouse_project_id
 from public.materials m join public.material_stock s on s.material_id=m.id join public.warehouses w on w.id=s.warehouse_id
 where m.deleted_at is null and m.is_active and w.is_active;

create or replace function public.nexo_import_materials(p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid();v_project public.projects%rowtype;v_warehouse public.warehouses%rowtype;
 v_material public.materials%rowtype;v_row jsonb;v_batch uuid;v_sku text;v_kind text;v_quantity numeric;v_price numeric;v_minimum numeric;
 v_mode text:=p_payload->>'mode';v_digest text:=p_payload->>'file_digest';v_count integer;
begin
 if v_user is null then raise exception 'Debes iniciar sesión.';end if;
 select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null;
 if not found or not private.can_access_project(v_project.id)
 or not private.has_permission(v_project.organization_id,'material.manage_stock',v_project.id,v_project.area_id)
 or not private.has_permission(v_project.organization_id,'material.manage_catalog',v_project.id,v_project.area_id) then raise exception 'No tienes permiso para importar materiales en este proyecto.';end if;
 if v_mode is null or v_mode not in ('initial','purchase') or v_digest is null or v_digest !~ '^[a-f0-9]{64}$' then raise exception 'Operación o archivo inválido.';end if;
 if nullif(trim(p_payload->>'file_name'),'') is null or length(p_payload->>'file_name')>255 then raise exception 'Nombre de archivo inválido.';end if;
 if jsonb_typeof(p_payload->'rows') is distinct from 'array' then raise exception 'Agrega materiales.';end if;
 v_count:=jsonb_array_length(p_payload->'rows');if v_count not between 1 and 1000 then raise exception 'Importa entre 1 y 1000 materiales.';end if;
 if exists(select 1 from jsonb_array_elements(p_payload->'rows') r group by upper(trim(r->>'sku')) having count(*)>1) then raise exception 'Hay códigos repetidos en el archivo.';end if;
 -- Serializa creación del almacén y compras concurrentes en el mismo destino.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_project.id::text,15));
 if nullif(p_payload->>'warehouse_id','') is null then
 insert into public.warehouses(organization_id,project_id,code,name)
 values(v_project.organization_id,v_project.id,'PRY-'||v_project.id::text,'Almacén · '||v_project.name)
 on conflict(organization_id,code) do nothing;
 select * into v_warehouse from public.warehouses where organization_id=v_project.organization_id and code='PRY-'||v_project.id::text for update;
 else
 select * into v_warehouse from public.warehouses where id=(p_payload->>'warehouse_id')::uuid for update;
 end if;
 if v_warehouse.id is null or not v_warehouse.is_active or v_warehouse.organization_id<>v_project.organization_id
 or (v_warehouse.project_id is not null and v_warehouse.project_id<>v_project.id)
 or (v_warehouse.project_id is null and not private.has_permission(v_project.organization_id,'material.manage_stock')) then raise exception 'Almacén fuera de tu alcance.';end if;
 if exists(select 1 from public.material_import_batches where organization_id=v_project.organization_id and warehouse_id=v_warehouse.id and file_digest=v_digest) then raise exception 'Este archivo ya fue importado en este almacén. No se duplicaron existencias.';end if;
 insert into public.material_import_batches(organization_id,project_id,warehouse_id,file_name,file_digest,mode,row_count,created_by)
 values(v_project.organization_id,v_project.id,v_warehouse.id,p_payload->>'file_name',v_digest,v_mode,v_count,v_user) returning id into v_batch;
 for v_row in select * from jsonb_array_elements(p_payload->'rows') order by upper(trim(value->>'sku')) loop
 v_sku:=upper(trim(v_row->>'sku'));v_kind:=v_row->>'kind';
 v_quantity:=(v_row->>'quantity')::numeric;v_price:=(v_row->>'price')::numeric;v_minimum:=(v_row->>'minimum')::numeric;
 if v_sku is null or length(v_sku) not between 1 and 40 or nullif(trim(v_row->>'name'),'') is null or length(v_row->>'name')>200
 or nullif(trim(v_row->>'unit'),'') is null or length(v_row->>'unit')>40 or v_kind is null or v_kind not in('consumable','returnable')
 or v_quantity is null or v_quantity<0 or v_quantity>1000000 or v_quantity<>round(v_quantity,4)
 or v_price is null or v_price<0 or v_price>1000000 or v_price<>round(v_price,4)
 or v_minimum is null or v_minimum<0 or v_minimum>1000000 or v_minimum<>round(v_minimum,4) then raise exception 'Datos inválidos en el material %.',coalesce(v_sku,'sin código');end if;
 insert into public.materials(organization_id,sku,name,unit_of_measure,material_kind,minimum_stock,standard_cost,requires_usage_report,requires_return,created_by)
 values(v_project.organization_id,v_sku,trim(v_row->>'name'),trim(v_row->>'unit'),v_kind,v_minimum,v_price,v_kind='consumable',v_kind='returnable',v_user)
 on conflict(organization_id,sku) do nothing;
 select * into v_material from public.materials where organization_id=v_project.organization_id and sku=v_sku for update;
 if not v_material.is_active or v_material.deleted_at is not null or v_material.material_kind<>v_kind or lower(v_material.unit_of_measure)<>lower(trim(v_row->>'unit')) then raise exception 'El código % existe con otra unidad o tipo, o está inactivo. Corrige el archivo.',v_sku;end if;
 if v_mode='initial' and (exists(select 1 from public.stock_movements where material_id=v_material.id and warehouse_id=v_warehouse.id)
 or exists(select 1 from public.material_stock where material_id=v_material.id and warehouse_id=v_warehouse.id and (on_hand>0 or reserved>0))) then raise exception 'El material % ya tiene existencias o movimientos. Usa Agregar ingreso.',v_sku;end if;
 insert into public.material_stock(material_id,warehouse_id,unit_cost) values(v_material.id,v_warehouse.id,v_price)
 on conflict(material_id,warehouse_id) do update set unit_cost=excluded.unit_cost;
 if v_quantity>0 then
 insert into public.stock_movements(organization_id,material_id,warehouse_id,movement_type_code,quantity,quantity_delta,balance_after,reference_type,reference_id,project_id,recorded_by,reason)
 values(v_project.organization_id,v_material.id,v_warehouse.id,v_mode,v_quantity,0,0,'material_import',v_batch,v_project.id,v_user,'Importación Excel: '||(p_payload->>'file_name'));
 end if;
 end loop;
 return v_batch;
end;$$;
revoke all on function public.nexo_import_materials(jsonb) from public,anon;
grant execute on function public.nexo_import_materials(jsonb) to authenticated;

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
  if p_command in ('request.create','request.update') then
    select * into v_project from public.projects where id = (p_payload->>'project_id')::uuid and deleted_at is null;
    if not found or not private.can_access_project(v_project.id) or not private.has_permission(v_project.organization_id, 'material.request', v_project.id, v_project.area_id) then
      raise exception 'No tienes permiso para solicitar en este proyecto.';
    end if;
    v_member := private.current_member_id(v_project.organization_id);
    if v_member is null then raise exception 'Debes ser miembro activo para solicitar materiales.';end if;
    if nullif(p_payload->>'task_id','') is not null and not exists(
      select 1 from public.tasks t where t.id=(p_payload->>'task_id')::uuid and t.project_id=v_project.id and t.deleted_at is null
      and (private.has_permission(v_project.organization_id,'task.manage',v_project.id,v_project.area_id) or exists(
        select 1 from public.task_assignees a where a.task_id=t.id and a.member_id=v_member and a.assignment_type in('responsible','collaborator')))
    ) then raise exception 'Selecciona una tarea de tu proyecto que tengas asignada.';end if;
    if (select count(distinct x->>'warehouse_id') from jsonb_array_elements(p_payload->'items') x)>1 then raise exception 'Usa un solo almacén por solicitud.';end if;
    if p_command='request.update' then
      select * into v_request from public.material_requests where id=(p_payload->>'id')::uuid and deleted_at is null for update;
      if not found or v_request.requested_by_member_id<>v_member or v_request.project_id<>v_project.id or v_request.status_code not in('draft','needs_changes') then raise exception 'Solo puedes editar tus borradores o pedidos devueltos.';end if;
      delete from public.material_request_items where request_id=v_request.id;
      v_id:=v_request.id;
      update public.material_requests set justification=trim(p_payload->>'justification'),priority_code=coalesce(nullif(p_payload->>'priority_code',''),'medium'),needed_at=nullif(p_payload->>'needed_at','')::timestamptz,task_id=nullif(p_payload->>'task_id','')::uuid where id=v_id;
    end if;
    if nullif(trim(p_payload->>'justification'), '') is null then raise exception 'Ingresa una justificación.'; end if;
    if jsonb_typeof(p_payload->'items') is distinct from 'array' then raise exception 'Agrega materiales.'; end if;
    if jsonb_array_length(p_payload->'items') not between 1 and 30 then raise exception 'Agrega entre 1 y 30 materiales.'; end if;
    if exists (select 1 from jsonb_array_elements(p_payload->'items') x group by x->>'material_id', x->>'warehouse_id' having count(*) > 1) then raise exception 'No repitas un material y almacén.'; end if;
    if p_command='request.create' then
    insert into public.material_requests(organization_id, request_number, project_id, requested_by_member_id,
      justification, priority_code, needed_at, created_by)
    values (v_project.organization_id, 'SOL-' || to_char(now(), 'YYYYMMDD') || '-' || left(extensions.gen_random_uuid()::text, 8),
      v_project.id, v_member, trim(p_payload->>'justification'), coalesce(nullif(p_payload->>'priority_code',''),'medium'),
      nullif(p_payload->>'needed_at','')::timestamptz, v_user)
    returning id into v_id;
    update public.material_requests set task_id=nullif(p_payload->>'task_id','')::uuid where id=v_id;
    end if;
    for v_entry in select * from jsonb_array_elements(p_payload->'items') loop
      v_qty := (v_entry->>'quantity')::numeric;
      if v_qty is null or v_qty <= 0 or v_qty > 1000000 then raise exception 'Cantidad inválida.'; end if;
      if not exists (select 1 from public.materials where id = (v_entry->>'material_id')::uuid and organization_id = v_project.organization_id and deleted_at is null and is_active)
        or not exists (select 1 from public.warehouses where id = (v_entry->>'warehouse_id')::uuid and organization_id = v_project.organization_id and is_active and (project_id is null or project_id=v_project.id)) then raise exception 'Material o almacén inválido.'; end if;
      insert into public.material_request_items(request_id, material_id, preferred_warehouse_id, quantity_requested, unit_cost)
      select v_id, id, (v_entry->>'warehouse_id')::uuid, v_qty, coalesce((select s.unit_cost from public.material_stock s where s.material_id=public.materials.id and s.warehouse_id=(v_entry->>'warehouse_id')::uuid),standard_cost,0)
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
    if v_flow is null then
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_request.organization_id::text,16));
      select id into v_flow from public.approval_flows where organization_id=v_request.organization_id and subject_type='material_request' and is_active order by created_at limit 1;
      if v_flow is null then
        insert into public.approval_flows(organization_id,code,name,subject_type,is_active) values(v_request.organization_id,'AUTO-MATERIALES','Materiales · jefe de proyecto','material_request',true) returning id into v_flow;
        insert into public.approval_flow_steps(flow_id,step_order,name,approver_type,role_id,minimum_approvals)
        select v_flow,1,'Revisión del jefe','role',id,1 from public.roles where organization_id=v_request.organization_id and code='project_manager';
      end if;
    end if;
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
    if not private.has_permission(v_request.organization_id,'approval.manage',v_project.id,v_project.area_id) and not private.has_permission(v_request.organization_id,'project.manage',v_project.id,v_project.area_id) and not exists (
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

  elsif p_command='request.receive' then
    if v_request.requested_by_member_id<>v_member or v_request.status_code<>'delivered' or v_request.received_at is not null then raise exception 'Solo el solicitante puede confirmar una entrega pendiente de recepción.';end if;
    update public.material_requests set received_at=now(),received_by_member_id=v_member where id=v_request.id;
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
