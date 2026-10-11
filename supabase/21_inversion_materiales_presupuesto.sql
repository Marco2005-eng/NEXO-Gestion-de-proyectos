-- Presupuesto, costos históricos de ingresos y ampliaciones. Ejecutar después del SQL 15.
begin;
insert into public.permissions(code,module,name,description) values
('project.manage_budget','projects','Administrar presupuesto','Configurar inversión y aprobar ampliaciones') on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='project.manage_budget' where r.code='admin' on conflict do nothing;
create or replace function private.nexo_admin_budget_permission() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.code='admin' then insert into public.role_permissions(role_id,permission_id) select new.id,id from public.permissions where code='project.manage_budget' on conflict do nothing;end if;return new;
end $$;
drop trigger if exists nexo_admin_budget_permission on public.roles;
create trigger nexo_admin_budget_permission after insert on public.roles for each row execute function private.nexo_admin_budget_permission();

create table if not exists public.project_material_costs(
 id uuid primary key default extensions.gen_random_uuid(),movement_id uuid not null unique references public.stock_movements(id),
 organization_id uuid not null references public.organizations(id),project_id uuid not null references public.projects(id),
 quantity numeric(18,4) not null check(quantity>0),unit_cost numeric(18,4) check(unit_cost>=0),
 amount numeric(18,4) generated always as (quantity*unit_cost) stored,
 recorded_at timestamptz not null,valued_by uuid references public.profiles(id),valued_at timestamptz,valuation_note text
);
create index if not exists project_material_costs_project_time_idx on public.project_material_costs(project_id,recorded_at desc,id);
alter table public.project_material_costs enable row level security;
drop policy if exists project_material_costs_select on public.project_material_costs;
create policy project_material_costs_select on public.project_material_costs for select to authenticated using(
 private.has_permission(organization_id,'report.view',project_id) or private.has_permission(organization_id,'material.manage_stock',project_id) or private.has_permission(organization_id,'project.manage',project_id));
grant select on public.project_material_costs to authenticated;
-- No se inventa el precio histórico de las compras anteriores: quedan por valorizar.
insert into public.project_material_costs(movement_id,organization_id,project_id,quantity,recorded_at)
select id,organization_id,project_id,quantity,occurred_at from public.stock_movements
where movement_type_code in ('initial','purchase') and project_id is not null on conflict(movement_id) do nothing;

create table if not exists public.project_budget_requests(
 id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id),project_id uuid not null references public.projects(id),
 amount numeric(18,4) not null check(amount>0),reason text not null check(length(trim(reason)) between 5 and 2000),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 requested_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),
 decided_by uuid references public.profiles(id),decided_at timestamptz,decision_note text
);
create index if not exists project_budget_requests_project_time_idx on public.project_budget_requests(project_id,created_at desc,id);
alter table public.project_budget_requests enable row level security;
drop policy if exists project_budget_requests_select on public.project_budget_requests;
create policy project_budget_requests_select on public.project_budget_requests for select to authenticated using(
 private.has_permission(organization_id,'report.view',project_id) or private.has_permission(organization_id,'project.manage',project_id) or private.has_permission(organization_id,'project.manage_budget',project_id));
grant select on public.project_budget_requests to authenticated;

create or replace function private.nexo_material_investment() returns trigger language plpgsql security definer set search_path='' as $$
declare v_budget numeric;v_spent numeric;v_price numeric;
begin
 if new.movement_type_code not in ('initial','purchase') or new.project_id is null then return new;end if;
 select budget into v_budget from public.projects where id=new.project_id for update;
 if v_budget is null then raise exception 'Configura el presupuesto del proyecto antes de registrar la inversión.';end if;
 if exists(select 1 from public.project_material_costs where project_id=new.project_id and unit_cost is null) then raise exception 'Hay ingresos anteriores sin costo histórico. El administrador debe valorizarlos en el balance antes de registrar más compras.';end if;
 select unit_cost into v_price from public.material_stock where material_id=new.material_id and warehouse_id=new.warehouse_id;
 if v_price is null then raise exception 'Indica el precio de compra para registrar la inversión.';end if;
 select coalesce(sum(amount),0) into v_spent from public.project_material_costs where project_id=new.project_id;
 if v_spent+new.quantity*v_price>v_budget then raise exception 'Presupuesto insuficiente. Disponible: S/ %. Ingreso: S/ %. Solicita una ampliación.',v_budget-v_spent,new.quantity*v_price;end if;
 insert into public.project_material_costs(movement_id,organization_id,project_id,quantity,unit_cost,recorded_at,valued_by,valued_at,valuation_note)
 values(new.id,new.organization_id,new.project_id,new.quantity,v_price,new.occurred_at,auth.uid(),now(),new.reason);
 return new;
end $$;
-- AFTER: stock y costo ya están definidos; cualquier error revierte toda la importación.
drop trigger if exists nexo_material_investment on public.stock_movements;
create trigger nexo_material_investment after insert on public.stock_movements for each row execute function private.nexo_material_investment();

create or replace function private.nexo_protect_project_budget() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.budget is distinct from old.budget and auth.uid() is not null and not private.has_permission(old.organization_id,'project.manage_budget',old.id,old.area_id) then raise exception 'Solo el administrador autorizado puede modificar el presupuesto. Solicita una ampliación.';end if;
 return new;
end $$;
drop trigger if exists nexo_protect_project_budget on public.projects;
create trigger nexo_protect_project_budget before update on public.projects for each row execute function private.nexo_protect_project_budget();

create or replace function public.nexo_budget_command(p_command text,p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_project public.projects;v_request public.project_budget_requests;v_cost public.project_material_costs;v_amount numeric;v_id uuid;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión.';end if;
 select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null for update;
 if not found or not private.can_access_project(v_project.id) then raise exception 'Proyecto no disponible.';end if;
 if p_command='budget.request' then
  if not private.has_permission(v_project.organization_id,'project.manage',v_project.id,v_project.area_id) then raise exception 'No puedes solicitar ampliaciones.';end if;
  v_amount:=(p_payload->>'amount')::numeric;
  if v_amount is null or v_amount<=0 or v_amount>1000000000 then raise exception 'Indica un importe válido.';end if;
  insert into public.project_budget_requests(organization_id,project_id,amount,reason,requested_by) values(v_project.organization_id,v_project.id,v_amount,trim(p_payload->>'reason'),auth.uid()) returning id into v_id;
 elsif p_command in ('budget.decide','budget.value','budget.set') then
  if not private.has_permission(v_project.organization_id,'project.manage_budget',v_project.id,v_project.area_id) then raise exception 'Solo el administrador autorizado puede realizar esta operación.';end if;
  if p_command='budget.decide' then
   select * into v_request from public.project_budget_requests where id=(p_payload->>'id')::uuid and project_id=v_project.id for update;
   if not found or v_request.status<>'pending' then raise exception 'La ampliación no está pendiente.';end if;
   if p_payload->>'decision' not in ('approved','rejected') or p_payload->>'decision' is null then raise exception 'Decisión inválida.';end if;
   if p_payload->>'decision'='rejected' and nullif(trim(p_payload->>'note'),'') is null then raise exception 'Indica el motivo del rechazo.';end if;
   if p_payload->>'decision'='approved' then update public.projects set budget=coalesce(budget,0)+v_request.amount where id=v_project.id;end if;
   update public.project_budget_requests set status=p_payload->>'decision',decided_by=auth.uid(),decided_at=now(),decision_note=p_payload->>'note' where id=v_request.id;v_id:=v_request.id;
  elsif p_command='budget.value' then
   select * into v_cost from public.project_material_costs where id=(p_payload->>'id')::uuid and project_id=v_project.id and unit_cost is null for update;
   if not found then raise exception 'El ingreso ya fue valorizado o no pertenece a este proyecto.';end if;
   v_amount:=(p_payload->>'unit_cost')::numeric;
   if v_amount is null or v_amount<0 or v_amount>1000000 or nullif(trim(p_payload->>'note'),'') is null then raise exception 'Indica precio histórico y sustento.';end if;
   update public.project_material_costs set unit_cost=v_amount,valued_by=auth.uid(),valued_at=now(),valuation_note=p_payload->>'note' where id=v_cost.id;v_id:=v_cost.id;
  else
   v_amount:=(p_payload->>'amount')::numeric;
   if v_amount is null or v_amount<0 or v_amount>1000000000 then raise exception 'Presupuesto inválido.';end if;
   update public.projects set budget=v_amount where id=v_project.id;v_id:=v_project.id;
  end if;
 else raise exception 'Operación inválida.';end if;
 return v_id;
end $$;
revoke all on function public.nexo_budget_command(text,jsonb) from public,anon;
grant execute on function public.nexo_budget_command(text,jsonb) to authenticated;

create or replace function public.nexo_material_entry(p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_project public.projects;v_material public.materials;v_id uuid;
begin
 select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null;
 if auth.uid() is null or not found or not private.can_access_project(v_project.id)
 or not private.has_permission(v_project.organization_id,'material.manage_catalog',v_project.id,v_project.area_id)
 or not private.has_permission(v_project.organization_id,'material.manage_stock',v_project.id,v_project.area_id) then raise exception 'No tienes permiso para gestionar materiales en este proyecto.';end if;
 if p_payload->>'operation'='edit' then
  select * into v_material from public.materials where id=(p_payload->>'material_id')::uuid and organization_id=v_project.organization_id and deleted_at is null for update;
  if not found or nullif(trim(p_payload->>'name'),'') is null or length(p_payload->>'name')>200 then raise exception 'Material o nombre inválido.';end if;
  if not private.has_permission(v_project.organization_id,'material.manage_catalog') and not exists(select 1 from public.material_stock s join public.warehouses w on w.id=s.warehouse_id where s.material_id=v_material.id and w.project_id=v_project.id) then raise exception 'Este material no pertenece al inventario del proyecto.';end if;
  update public.materials set name=trim(p_payload->>'name'),minimum_stock=(p_payload->>'minimum')::numeric where id=v_material.id;
  return v_material.id;
 end if;
 if p_payload->>'operation' not in ('initial','purchase') then raise exception 'Operación inválida.';end if;
 v_id:=public.nexo_import_materials(jsonb_build_object('project_id',v_project.id,'warehouse_id',p_payload->>'warehouse_id','mode',p_payload->>'operation','file_name','Ingreso manual'||case when nullif(trim(p_payload->>'reference'),'') is null then '' else ' · '||left(trim(p_payload->>'reference'),180) end,'file_digest',p_payload->>'digest','rows',jsonb_build_array(jsonb_build_object('sku',p_payload->>'sku','name',p_payload->>'name','unit',p_payload->>'unit','kind',p_payload->>'kind','quantity',(p_payload->>'quantity')::numeric,'price',(p_payload->>'price')::numeric,'minimum',(p_payload->>'minimum')::numeric))));
 return v_id;
end $$;
revoke all on function public.nexo_material_entry(jsonb) from public,anon;
grant execute on function public.nexo_material_entry(jsonb) to authenticated;

create or replace function private.nexo_check_approved_materials() returns trigger language plpgsql security definer set search_path='' as $$
declare v_item record;v_available numeric;
begin
 if new.status_code='approved' and old.status_code is distinct from 'approved' then
  for v_item in select * from public.material_request_items where request_id=new.id order by material_id,preferred_warehouse_id loop
   select on_hand-reserved into v_available from public.material_stock where material_id=v_item.material_id and warehouse_id=v_item.preferred_warehouse_id for update;
   if v_available is null or v_available<coalesce(v_item.quantity_approved,v_item.quantity_requested) then raise exception 'Stock disponible insuficiente para aprobar. Registra una compra o corrige las cantidades; verifica el presupuesto del proyecto.';end if;
  end loop;
 end if;return new;
end $$;
drop trigger if exists nexo_check_approved_materials on public.material_requests;
create trigger nexo_check_approved_materials before update on public.material_requests for each row execute function private.nexo_check_approved_materials();


create or replace function public.nexo_project_balance(p_project_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_project public.projects;v_costs jsonb;v_requests jsonb;v_spent numeric;v_missing integer;
begin
 select * into v_project from public.projects where id=p_project_id and deleted_at is null;
 if auth.uid() is null or not found or not private.can_access_project(p_project_id) or not (
 private.has_permission(v_project.organization_id,'report.view',p_project_id,v_project.area_id) or private.has_permission(v_project.organization_id,'project.manage',p_project_id,v_project.area_id) or private.has_permission(v_project.organization_id,'material.manage_stock',p_project_id,v_project.area_id) or private.has_permission(v_project.organization_id,'project.manage_budget',p_project_id,v_project.area_id)) then raise exception 'No puedes consultar el balance de este proyecto.';end if;
 select coalesce(sum(amount),0),count(*) filter(where unit_cost is null) into v_spent,v_missing from public.project_material_costs where project_id=p_project_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'material',m.name,'sku',m.sku,'quantity',c.quantity,'unit',m.unit_of_measure,'unit_cost',c.unit_cost,'amount',c.amount,'date',c.recorded_at,'type',s.movement_type_code,'warehouse',w.name,'note',c.valuation_note) order by c.recorded_at desc,c.id),'[]'::jsonb) into v_costs
 from public.project_material_costs c join public.stock_movements s on s.id=c.movement_id join public.materials m on m.id=s.material_id join public.warehouses w on w.id=s.warehouse_id where c.project_id=p_project_id;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) into v_requests from public.project_budget_requests r where r.project_id=p_project_id;
 return jsonb_build_object('project_id',v_project.id,'name',v_project.name,'budget',v_project.budget,'spent',v_spent,'missing',v_missing,'remaining',case when v_missing=0 and v_project.budget is not null then v_project.budget-v_spent else null end,'costs',v_costs,'requests',v_requests);
end $$;
revoke all on function public.nexo_project_balance(uuid) from public,anon;
grant execute on function public.nexo_project_balance(uuid) to authenticated;


create or replace function private.nexo_budget_notifications() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
  select new.organization_id,u.user_id,'budget.pending','Ampliación de presupuesto pendiente',new.reason,'/materiales?proyecto='||new.project_id::text
  from (select user_id from public.organization_members where organization_id=new.organization_id and status='active' and private.has_permission(new.organization_id,'project.manage_budget',new.project_id,null,user_id)
        union select user_id from public.platform_administrators) u where u.user_id is distinct from new.requested_by;
 elsif new.status is distinct from old.status then
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
  values(new.organization_id,new.requested_by,'budget.updated','Ampliación de presupuesto actualizada',case when new.status='approved' then 'Aprobada: S/ ' else 'Rechazada: S/ ' end||new.amount::text,'/materiales?proyecto='||new.project_id::text);
 end if;return new;
end $$;
drop trigger if exists nexo_budget_notifications on public.project_budget_requests;
create trigger nexo_budget_notifications after insert or update on public.project_budget_requests for each row execute function private.nexo_budget_notifications();

commit;
