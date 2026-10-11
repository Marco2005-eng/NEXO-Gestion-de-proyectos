-- Ejecuta después de 11_organizaciones_superadministrador.sql y las mejoras anteriores.
-- Permisos editables por organización. Crear no da acceso a otros proyectos.
begin;
create or replace function public.nexo_role_command(p_command text,p_payload jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_org uuid := (p_payload->>'organization_id')::uuid;
  v_id uuid; v_role public.roles; v_assignment public.member_role_assignments;
  v_scope text := coalesce(p_payload->>'scope_type','organization');
begin
  if auth.uid() is null or not private.has_permission(v_org,'access.manage') then
    raise exception 'No tienes permiso para administrar los roles de esta organización';
  end if;
  -- Serializa los cambios para conservar al menos un administrador.
  perform 1 from public.organizations where id=v_org for update;
  if p_command='role.save' then
    if length(trim(coalesce(p_payload->>'name','')))=0 or length(p_payload->>'name')>100 then raise exception 'Indica un nombre de rol válido'; end if;
    v_id:=nullif(p_payload->>'id','')::uuid;
    if v_id is not null then
      select * into v_role from public.roles where id=v_id and organization_id=v_org for update;
      if not found then raise exception 'Rol no encontrado en esta organización'; end if;
      if not v_role.is_system then update public.roles set name=trim(p_payload->>'name'),description=p_payload->>'description' where id=v_id; end if;
    else
      insert into public.roles(organization_id,code,name,description)
      values(v_org,'custom_'||extensions.gen_random_uuid()::text,trim(p_payload->>'name'),p_payload->>'description') returning id into v_id;
    end if;
    if jsonb_typeof(p_payload->'permission_ids') is distinct from 'array' then raise exception 'Selecciona los permisos del rol'; end if;
    delete from public.role_permissions where role_id=v_id;
    insert into public.role_permissions(role_id,permission_id,granted_by)
      select distinct v_id,value::uuid,auth.uid() from jsonb_array_elements_text(p_payload->'permission_ids');
    -- Conserva el control de accesos del administrador incluso al editar su rol.
    if exists(select 1 from public.roles where id=v_id and code='admin') then
      insert into public.role_permissions(role_id,permission_id,granted_by)
      select v_id,id,auth.uid() from public.permissions where code='access.manage' on conflict do nothing;
    end if;
  elsif p_command in ('role.assign','role.replace') then
    select * into v_role from public.roles where id=(p_payload->>'role_id')::uuid and organization_id=v_org and is_active;
    if not found then raise exception 'El rol no está disponible'; end if;
    if v_role.code='admin' and v_scope<>'organization' then raise exception 'Administrador requiere alcance de organización'; end if;
    if not exists(select 1 from public.organization_members where id=(p_payload->>'member_id')::uuid and organization_id=v_org and status='active') then raise exception 'Selecciona un miembro activo'; end if;
    if p_command='role.replace' then
      -- Solo reemplaza accesos en el alcance elegido; conserva los demás proyectos.
      update public.member_role_assignments set valid_until=greatest(clock_timestamp(),valid_from+interval '1 microsecond')
      where organization_id=v_org and member_id=(p_payload->>'member_id')::uuid and role_id<>v_role.id and scope_type=v_scope
      and project_id is not distinct from nullif(p_payload->>'project_id','')::uuid
      and area_id is not distinct from nullif(p_payload->>'area_id','')::uuid
      and (valid_until is null or valid_until>now());
    end if;
    select id into v_id from public.member_role_assignments where member_id=(p_payload->>'member_id')::uuid and role_id=v_role.id and scope_type=v_scope
      and project_id is not distinct from nullif(p_payload->>'project_id','')::uuid and area_id is not distinct from nullif(p_payload->>'area_id','')::uuid
      and valid_from<=now() and (valid_until is null or valid_until>now()) limit 1;
    if v_id is null then
      insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,area_id,assigned_by)
      values(v_org,(p_payload->>'member_id')::uuid,v_role.id,v_scope,nullif(p_payload->>'project_id','')::uuid,nullif(p_payload->>'area_id','')::uuid,auth.uid()) returning id into v_id;
    elsif p_command='role.assign' then raise exception 'El usuario ya tiene este rol en ese alcance';
    end if;
  elsif p_command='role.revoke' then
    select * into v_assignment from public.member_role_assignments where id=(p_payload->>'id')::uuid and organization_id=v_org for update;
    if not found then raise exception 'Asignación no encontrada'; end if;
    update public.member_role_assignments set valid_until=greatest(clock_timestamp(),valid_from+interval '1 microsecond') where id=v_assignment.id returning id into v_id;
  else raise exception 'Operación de rol inválida'; end if;
  return v_id;
end $$;
revoke all on function public.nexo_role_command(text,jsonb) from public,anon;
grant execute on function public.nexo_role_command(text,jsonb) to authenticated;


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
        or (a.scope_type = 'project' and (a.project_id = p_project_id or (p_permission_code = 'project.create' and exists(select 1 from public.projects existing_project where existing_project.id=a.project_id and existing_project.organization_id=m.organization_id and existing_project.deleted_at is null))))
      )
  ));
$$;

-- INSERT ... RETURNING comprueba la lectura antes del trigger AFTER INSERT.
-- Permite leer únicamente los proyectos creados por el usuario en su organización.
drop policy if exists projects_creator_select on public.projects;
create policy projects_creator_select on public.projects for select to authenticated
using (created_by=auth.uid() and private.has_permission(organization_id,'project.create',null,area_id));

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='project.create'
where r.code='project_manager' on conflict do nothing;

create or replace function private.nexo_project_manager_creation_permission()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.code='project_manager' then
  insert into public.role_permissions(role_id,permission_id)
  select new.id,id from public.permissions where code='project.create' on conflict do nothing;
 end if;
 return new;
end $$;
drop trigger if exists nexo_project_manager_creation_permission on public.roles;
create trigger nexo_project_manager_creation_permission after insert on public.roles
for each row execute function private.nexo_project_manager_creation_permission();

create or replace function private.nexo_created_project_lead()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_member uuid; v_role uuid;
begin
 -- Solo el creador autenticado con rol de jefe recibe el nuevo proyecto.
 if auth.uid() is null or new.created_by is distinct from auth.uid() then return new; end if;
 select m.id,r.id into v_member,v_role
 from public.organization_members m
 join public.member_role_assignments a on a.member_id=m.id and a.organization_id=m.organization_id
 join public.roles r on r.id=a.role_id and r.organization_id=m.organization_id
 where m.organization_id=new.organization_id and m.user_id=auth.uid() and m.status='active'
 and r.code='project_manager' and r.is_active and a.valid_from<=now() and (a.valid_until is null or a.valid_until>now())
 limit 1;
 if v_member is not null then
  insert into public.project_members(project_id,member_id,project_title,is_project_manager,created_by)
  values(new.id,v_member,'Jefe de proyecto',true,auth.uid());
  insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,assigned_by)
  values(new.organization_id,v_member,v_role,'project',new.id,auth.uid());
  update public.projects set manager_member_id=v_member where id=new.id;
 end if;
 return new;
end $$;
drop trigger if exists nexo_created_project_lead on public.projects;
create trigger nexo_created_project_lead after insert on public.projects
for each row execute function private.nexo_created_project_lead();
commit;
