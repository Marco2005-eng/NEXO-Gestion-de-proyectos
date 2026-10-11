-- Centro de notificaciones y administración de roles de Nexo.
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
  elsif p_command='role.assign' then
    select * into v_role from public.roles where id=(p_payload->>'role_id')::uuid and organization_id=v_org and is_active;
    if not found then raise exception 'El rol no está disponible'; end if;
    if v_role.code='admin' and v_scope<>'organization' then raise exception 'Administrador requiere alcance de organización'; end if;
    if not exists(select 1 from public.organization_members where id=(p_payload->>'member_id')::uuid and organization_id=v_org and status='active') then raise exception 'Selecciona un miembro activo'; end if;
    if exists(select 1 from public.member_role_assignments where member_id=(p_payload->>'member_id')::uuid and role_id=v_role.id and scope_type=v_scope and project_id is not distinct from nullif(p_payload->>'project_id','')::uuid and area_id is not distinct from nullif(p_payload->>'area_id','')::uuid and valid_from<=now() and (valid_until is null or valid_until>now())) then raise exception 'El usuario ya tiene este rol en ese alcance'; end if;
    insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,area_id,assigned_by)
    values(v_org,(p_payload->>'member_id')::uuid,v_role.id,v_scope,nullif(p_payload->>'project_id','')::uuid,nullif(p_payload->>'area_id','')::uuid,auth.uid()) returning id into v_id;
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
    and old.scope_type='organization' and old.valid_from<=now() and (old.valid_until is null or old.valid_until>now()) then
    perform 1 from public.organizations where id=old.organization_id for update;
    if tg_op='UPDATE' and new.member_id=old.member_id and new.role_id=old.role_id and new.organization_id=old.organization_id and new.scope_type='organization' and new.valid_from<=now() and (new.valid_until is null or new.valid_until>now()+interval '1 second') then return new; end if;
    if not exists(select 1 from public.member_role_assignments a join public.roles r on r.id=a.role_id join public.organization_members m on m.id=a.member_id
      where a.organization_id=old.organization_id and a.id<>old.id and a.scope_type='organization' and r.code='admin' and r.is_active and m.status='active' and a.valid_from<=now() and (a.valid_until is null or a.valid_until>now())) then
      raise exception 'No puedes revocar al último administrador de la organización';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if; return new;
end $$;
drop trigger if exists protect_last_admin on public.member_role_assignments;
create trigger protect_last_admin before update or delete on public.member_role_assignments for each row execute function private.protect_last_admin();

create or replace function private.nexo_notify_changes()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_user uuid; v_title text; v_body text; v_url text;
begin
  if tg_table_name='task_assignees' then
    if new.assignment_type<>'responsible' then return new; end if;
    select p.organization_id,'Tarea asignada',t.title,'/tareas' into v_org,v_title,v_body,v_url from public.tasks t join public.projects p on p.id=t.project_id where t.id=new.task_id;
    select user_id into v_user from public.organization_members where id=new.member_id;
  elsif tg_table_name='project_members' then
    if new.left_at is not null then return new; end if;
    if tg_op='UPDATE' and old.left_at is null then return new; end if;
    select organization_id,'Te agregaron a un proyecto',name,'/proyectos' into v_org,v_title,v_body,v_url from public.projects where id=new.project_id;
    select user_id into v_user from public.organization_members where id=new.member_id;
  elsif tg_table_name='material_requests' then
    if new.status_code is not distinct from old.status_code then return new; end if;
    v_org:=new.organization_id;v_title:='Actualización de solicitud';v_body:=new.request_number||' · '||new.status_code;v_url:='/solicitudes';
    select user_id into v_user from public.organization_members where id=new.requested_by_member_id;
    if new.status_code='pending' then
      insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
      select v_org,m.user_id,'approval.pending','Solicitud pendiente de aprobación',new.request_number,'/aprobaciones'
      from public.organization_members m where m.organization_id=v_org and m.status='active' and m.user_id is distinct from auth.uid() and private.has_permission(v_org,'material.approve',new.project_id,null,m.user_id);
    end if;
  elsif tg_table_name='member_role_assignments' then
    if tg_op='UPDATE' and new.valid_until is not distinct from old.valid_until then return new; end if;
    v_org:=new.organization_id;v_title:=case when tg_op='INSERT' then 'Nuevo rol asignado' else 'Acceso actualizado' end;
    select name||' · '||new.scope_type into v_body from public.roles where id=new.role_id;
    v_url:='/administracion'; select user_id into v_user from public.organization_members where id=new.member_id;
  end if;
  if v_user is not null then
    insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
    values(v_org,v_user,tg_table_name,v_title,v_body,v_url);
  end if;
  return new;
end $$;
drop trigger if exists nexo_notify on public.task_assignees;
create trigger nexo_notify after insert on public.task_assignees for each row execute function private.nexo_notify_changes();
drop trigger if exists nexo_notify on public.project_members;
create trigger nexo_notify after insert or update on public.project_members for each row execute function private.nexo_notify_changes();
drop trigger if exists nexo_notify on public.material_requests;
create trigger nexo_notify after update on public.material_requests for each row execute function private.nexo_notify_changes();
drop trigger if exists nexo_notify on public.member_role_assignments;
create trigger nexo_notify after insert or update on public.member_role_assignments for each row execute function private.nexo_notify_changes();
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;
commit;
