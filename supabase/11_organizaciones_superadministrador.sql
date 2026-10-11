-- Nexo: proveedor del servicio, organizaciones y jefes de proyecto.
begin;
create table if not exists public.platform_administrators(user_id uuid primary key references public.profiles(id) on delete cascade,created_at timestamptz not null default now());
alter table public.platform_administrators enable row level security;
drop policy if exists platform_admin_self on public.platform_administrators;
create policy platform_admin_self on public.platform_administrators for select to authenticated using(user_id=auth.uid());
grant select on public.platform_administrators to authenticated;
revoke insert,update,delete on public.platform_administrators from authenticated,anon;
create or replace function private.is_platform_admin(p_user_id uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.platform_administrators where user_id=p_user_id); $$;
revoke all on function private.is_platform_admin(uuid) from public,anon;
grant execute on function private.is_platform_admin(uuid) to authenticated,service_role;
create or replace function public.nexo_is_platform_admin() returns boolean language sql stable security definer set search_path='' as $$ select private.is_platform_admin(auth.uid()); $$;
revoke all on function public.nexo_is_platform_admin() from public,anon;
grant execute on function public.nexo_is_platform_admin() to authenticated;
create or replace function private.is_org_member(p_organization_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin(p_user_id) or (p_user_id is not null and exists (
    select 1 from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
  ));
$$;
create or replace function private.shares_organization(p_other_user_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin(p_user_id) or (p_user_id is not null and exists (
    select 1
    from public.organization_members me
    join public.organization_members other_member on other_member.organization_id = me.organization_id
    where me.user_id = p_user_id and me.status = 'active'
      and other_member.user_id = p_other_user_id and other_member.status = 'active'
  ));
$$;
create or replace function private.has_permission(
  p_organization_id uuid,
  p_permission_code text,
  p_project_id uuid default null,
  p_area_id uuid default null,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin(p_user_id) or (p_user_id is not null and exists (
    select 1
    from public.organization_members m
    join public.member_role_assignments a on a.member_id = m.id and a.organization_id = m.organization_id
    join public.roles r on r.id = a.role_id and r.organization_id = m.organization_id and r.is_active
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id and p.code = p_permission_code
    left join public.projects scope_project on scope_project.id = p_project_id
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
      and a.valid_from <= now()
      and (a.valid_until is null or a.valid_until > now())
      and (
        a.scope_type = 'organization'
        or (a.scope_type = 'area' and a.area_id = coalesce(p_area_id, scope_project.area_id))
        or (a.scope_type = 'project' and a.project_id = p_project_id)
      )
  ));
$$;
create or replace function private.can_access_project(p_project_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin(p_user_id) or (p_user_id is not null and exists (
    select 1
    from public.projects p
    join public.organization_members m on m.organization_id = p.organization_id
    where p.id = p_project_id
      and p.deleted_at is null
      and m.user_id = p_user_id
      and m.status = 'active'
      and (
        exists (select 1 from public.project_members pm where pm.project_id = p.id and pm.member_id = m.id and pm.left_at is null)
        or private.has_permission(p.organization_id, 'project.view', p.id, p.area_id, p_user_id)
      )
  ));
$$;
create or replace function private.can_access_material_request(p_request_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin(p_user_id) or (p_user_id is not null and exists (
    select 1
    from public.material_requests r
    join public.organization_members m on m.organization_id = r.organization_id and m.user_id = p_user_id and m.status = 'active'
    where r.id = p_request_id
      and r.deleted_at is null
      and (
        r.requested_by_member_id = m.id
        or private.has_permission(r.organization_id, 'material.view', r.project_id, null, p_user_id)
        or private.has_permission(r.organization_id, 'material.approve', r.project_id, null, p_user_id)
      )
  ));
$$;

create or replace function private.bootstrap_organization(p_name text, p_slug text, p_owner_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_member_id uuid;
  v_role_id uuid;
  v_role record;
begin
  if p_owner_user_id is null or not exists (select 1 from public.profiles where id = p_owner_user_id) then
    raise exception 'El propietario debe existir en profiles';
  end if;

  insert into public.organizations(name, slug, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_owner_user_id)
  returning id into v_org_id;

  insert into public.organization_members(organization_id, user_id, status, joined_at)
  values (v_org_id, p_owner_user_id, 'active', now()) returning id into v_member_id;

  for v_role in select * from (values
    ('admin', 'Administrador', 'Control completo de la organización'),
    ('project_manager', 'Jefe de proyecto', 'Gestión de sus proyectos'),
    ('area_manager', 'Jefe de área', 'Gestión dentro de su área'),
    ('approver', 'Aprobador', 'Decisión de solicitudes asignadas'),
    ('member', 'Miembro', 'Trabajo operativo en proyectos'),
    ('material_manager', 'Gestor de materiales', 'Catálogo, almacén y entregas'),
    ('auditor', 'Auditor', 'Consulta y auditoría sin edición')
  ) as x(code, name, description)
  loop
    insert into public.roles(organization_id, code, name, description, is_system)
    values (v_org_id, v_role.code, v_role.name, v_role.description, true);
  end loop;

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id
  from public.roles r cross join public.permissions p
  where r.organization_id = v_org_id and r.code = 'admin';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','project.manage','task.view','task.create','task.manage','user.invite',
    'material.view','material.request','approval.view','document.view','document.manage','diagram.view','diagram.manage',
    'report.view','report.export'
  ]) where r.organization_id = v_org_id and r.code = 'project_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','task.create','task.manage','material.view','material.request',
    'approval.view','document.view','document.manage','diagram.view','diagram.manage','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'area_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','material.view','material.approve','approval.view','approval.decide','document.view','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'approver';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','task.create','task.update_own','material.view','material.request',
    'document.view','document.manage','diagram.view'
  ]) where r.organization_id = v_org_id and r.code = 'member';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','material.view','material.request','material.manage_catalog','material.manage_stock',
    'approval.view','document.view','report.view'
  ]) where r.organization_id = v_org_id and r.code = 'material_manager';

  insert into public.role_permissions(role_id, permission_id, granted_by)
  select r.id, p.id, p_owner_user_id from public.roles r join public.permissions p on p.code = any(array[
    'organization.view','area.view','project.view','task.view','material.view','approval.view','document.view','diagram.view','report.view','report.export','audit.view'
  ]) where r.organization_id = v_org_id and r.code = 'auditor';

  select id into v_role_id from public.roles where organization_id = v_org_id and code = 'admin';
  insert into public.member_role_assignments(organization_id, member_id, role_id, scope_type, assigned_by)
  values (v_org_id, v_member_id, v_role_id, 'organization', p_owner_user_id);
  return v_org_id;
end;
$$;
-- Los jefes pueden registrar colaboradores, solo en el alcance de sus proyectos.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='user.invite' where r.code='project_manager'
on conflict do nothing;
create or replace function public.nexo_platform_users() returns table(id uuid,display_name text,email text) language plpgsql security definer set search_path='' as $$
begin if not private.is_platform_admin() then raise exception 'Solo el superadministrador puede consultar las cuentas del sistema'; end if;
return query select p.id,p.display_name,u.email::text from public.profiles p join auth.users u on u.id=p.id where p.is_active order by p.display_name; end $$;
revoke all on function public.nexo_platform_users() from public,anon;
grant execute on function public.nexo_platform_users() to authenticated;
create or replace function public.nexo_organization_command(p_command text,p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_org uuid:=nullif(p_payload->>'organization_id','')::uuid; v_project public.projects;v_member uuid;v_role uuid;v_id uuid;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 if p_command='organization.create' then
  if not private.is_platform_admin() then raise exception 'Solo el superadministrador crea organizaciones'; end if;
  if length(trim(coalesce(p_payload->>'name','')))=0 or length(p_payload->>'name')>150 or coalesce(p_payload->>'slug','')!~'^[a-z0-9][a-z0-9-]{2,59}$' then raise exception 'Revisa el nombre y código de la organización'; end if;
  v_id:=private.bootstrap_organization(p_payload->>'name',p_payload->>'slug',(p_payload->>'owner_user_id')::uuid);
  -- Incluye permisos para registrar colaboradores en organizaciones nuevas.
  insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r join public.permissions p on p.code='user.invite' where r.organization_id=v_id and r.code='project_manager' on conflict do nothing;
 elsif p_command='organization.rename' then
  if not private.has_permission(v_org,'organization.manage') then raise exception 'No puedes configurar esta organización'; end if;
  if length(trim(coalesce(p_payload->>'name','')))=0 or length(p_payload->>'name')>150 then raise exception 'Indica un nombre válido'; end if;
  update public.organizations set name=trim(p_payload->>'name') where id=v_org and deleted_at is null returning id into v_id;
  if v_id is null then raise exception 'Organización no disponible'; end if;
 elsif p_command='project.lead' then
  select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and organization_id=v_org and deleted_at is null for update;
  if not found or not private.has_permission(v_org,'access.manage') or not private.has_permission(v_org,'project.manage',v_project.id,v_project.area_id) then raise exception 'No puedes asignar el jefe de este proyecto'; end if;
  v_member:=(p_payload->>'member_id')::uuid;
  if not exists(select 1 from public.organization_members where id=v_member and organization_id=v_org and status='active') then raise exception 'El jefe debe ser un miembro activo de la organización'; end if;
  select id into v_role from public.roles where organization_id=v_org and code='project_manager' and is_active;
  if v_role is null then raise exception 'Rol de jefe de proyecto no disponible'; end if;
  update public.project_members set is_project_manager=false where project_id=v_project.id and member_id<>v_member;
  update public.member_role_assignments set valid_until=greatest(clock_timestamp(),valid_from+interval '1 microsecond') where organization_id=v_org and project_id=v_project.id and role_id=v_role and member_id<>v_member and scope_type='project' and (valid_until is null or valid_until>now());
  insert into public.project_members(project_id,member_id,project_title,is_project_manager,created_by) values(v_project.id,v_member,'Jefe de proyecto',true,auth.uid()) on conflict(project_id,member_id) do update set is_project_manager=true,project_title='Jefe de proyecto',left_at=null;
  if not exists(select 1 from public.member_role_assignments where role_id=v_role and member_id=v_member and project_id=v_project.id and scope_type='project' and valid_from<=now() and (valid_until is null or valid_until>now())) then
   insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,assigned_by) values(v_org,v_member,v_role,'project',v_project.id,auth.uid());
  end if; v_id:=v_project.id;
 else raise exception 'Operación inválida'; end if; return v_id;
end $$;
revoke all on function public.nexo_organization_command(text,jsonb) from public,anon;
grant execute on function public.nexo_organization_command(text,jsonb) to authenticated;
create or replace function public.nexo_list_project_users(p_project_id uuid) returns table(id uuid,organization_id uuid,user_id uuid,display_name text,email text,status text,job_title text) language plpgsql security definer set search_path='' as $$
declare v_org uuid;v_area uuid;
begin select p.organization_id,p.area_id into v_org,v_area from public.projects p where p.id=p_project_id and p.deleted_at is null;
 if v_org is null or not private.has_permission(v_org,'user.invite',p_project_id,v_area) or not private.has_permission(v_org,'project.manage',p_project_id,v_area) then raise exception 'No puedes registrar colaboradores en ese proyecto'; end if;
 return query select m.id,m.organization_id,m.user_id,p.display_name,u.email::text,m.status,m.job_title from public.project_members pm join public.organization_members m on m.id=pm.member_id join public.profiles p on p.id=m.user_id join auth.users u on u.id=p.id where pm.project_id=p_project_id and pm.left_at is null and m.status='active';
end $$;
revoke all on function public.nexo_list_project_users(uuid) from public,anon;
grant execute on function public.nexo_list_project_users(uuid) to authenticated;
create or replace function public.nexo_attach_project_user(p_organization_id uuid,p_user_id uuid,p_actor_id uuid,p_job_title text,p_project_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_project public.projects;v_member uuid;v_role uuid;
begin
 select * into v_project from public.projects where id=p_project_id and organization_id=p_organization_id and deleted_at is null for update;
 if not found or not private.has_permission(p_organization_id,'user.invite',p_project_id,v_project.area_id,p_actor_id) or not private.has_permission(p_organization_id,'project.manage',p_project_id,v_project.area_id,p_actor_id) then raise exception 'No puedes registrar colaboradores en ese proyecto'; end if;
 if not exists(select 1 from public.profiles where id=p_user_id and is_active) then raise exception 'Perfil no disponible'; end if;
 select id into v_role from public.roles where organization_id=p_organization_id and code='member' and is_active;
 if v_role is null then raise exception 'Rol de colaborador no disponible'; end if;
 insert into public.organization_members(organization_id,user_id,status,job_title,invited_by,joined_at) values(p_organization_id,p_user_id,'active',nullif(trim(p_job_title),''),p_actor_id,now()) returning id into v_member;
 insert into public.project_members(project_id,member_id,project_title,created_by) values(p_project_id,v_member,nullif(trim(p_job_title),''),p_actor_id);
 insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,assigned_by) values(p_organization_id,v_member,v_role,'project',p_project_id,p_actor_id);
 return v_member;
end $$;
revoke all on function public.nexo_attach_project_user(uuid,uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.nexo_attach_project_user(uuid,uuid,uuid,text,uuid) to service_role;
revoke all on function private.bootstrap_organization(text,text,uuid) from public,anon,authenticated;
grant execute on function private.bootstrap_organization(text,text,uuid) to service_role;
commit;
