-- Ejecutar después de 07_notificaciones_roles.sql. Cambiar rol reemplaza los accesos del mismo alcance.
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
      if not found or v_role.is_system then raise exception 'Los roles del sistema son de consulta; crea un rol personalizado'; end if;
      update public.roles set name=trim(p_payload->>'name'),description=p_payload->>'description' where id=v_id;
    else
      insert into public.roles(organization_id,code,name,description)
      values(v_org,'custom_'||extensions.gen_random_uuid()::text,trim(p_payload->>'name'),p_payload->>'description') returning id into v_id;
    end if;
    if jsonb_typeof(p_payload->'permission_ids') is distinct from 'array' then raise exception 'Selecciona los permisos del rol'; end if;
    delete from public.role_permissions where role_id=v_id;
    insert into public.role_permissions(role_id,permission_id,granted_by)
      select distinct v_id,value::uuid,auth.uid() from jsonb_array_elements_text(p_payload->'permission_ids');
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


create or replace function private.protect_last_admin()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.roles where id=old.role_id and code='admin' and is_active)
    and old.scope_type='organization' and old.valid_from<=clock_timestamp() and (old.valid_until is null or old.valid_until>clock_timestamp()) then
    perform 1 from public.organizations where id=old.organization_id for update;
    if tg_op='UPDATE' and new.member_id=old.member_id and new.role_id=old.role_id and new.organization_id=old.organization_id and new.scope_type='organization' and new.valid_from<=clock_timestamp() and (new.valid_until is null or new.valid_until>clock_timestamp()+interval '1 second') then return new; end if;
    if not exists(select 1 from public.member_role_assignments a join public.roles r on r.id=a.role_id join public.organization_members m on m.id=a.member_id
      where a.organization_id=old.organization_id and a.id<>old.id and a.scope_type='organization' and r.code='admin' and r.is_active and m.status='active' and a.valid_from<=clock_timestamp() and (a.valid_until is null or a.valid_until>clock_timestamp())) then
      raise exception 'No puedes revocar al último administrador de la organización';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if; return new;
end $$;
drop trigger if exists protect_last_admin on public.member_role_assignments;
create trigger protect_last_admin before update or delete on public.member_role_assignments for each row execute function private.protect_last_admin();


commit;
