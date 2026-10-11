-- Nexo: registro de miembros y asignación de equipo/tareas por proyecto.
begin;

create or replace function public.nexo_list_members(p_organization_id uuid)
returns table(id uuid, organization_id uuid, user_id uuid, display_name text, email text, status text, job_title text)
language plpgsql security definer set search_path = '' as $$
begin
  if not private.has_permission(p_organization_id,'user.manage') and not private.has_permission(p_organization_id,'user.invite') then
    raise exception 'No tienes permiso para consultar cuentas de esta organización.';
  end if;
  return query select m.id,m.organization_id,m.user_id,p.display_name,u.email::text,m.status,m.job_title
    from public.organization_members m join public.profiles p on p.id=m.user_id join auth.users u on u.id=m.user_id
    where m.organization_id=p_organization_id order by p.display_name;
end; $$;
revoke all on function public.nexo_list_members(uuid) from public, anon;
grant execute on function public.nexo_list_members(uuid) to authenticated;

-- Solo el servidor con Secret key puede vincular una cuenta recién registrada.
create or replace function public.nexo_attach_registered_user(p_organization_id uuid, p_user_id uuid, p_actor_id uuid, p_job_title text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_member uuid;
begin
  if not private.has_permission(p_organization_id,'user.invite',null,null,p_actor_id) then raise exception 'No puedes registrar usuarios en esta organización.'; end if;
  if not exists(select 1 from public.profiles where id=p_user_id and is_active) then raise exception 'La cuenta no tiene un perfil activo.'; end if;
  insert into public.organization_members(organization_id,user_id,status,job_title,invited_by,joined_at)
    values(p_organization_id,p_user_id,'active',nullif(trim(p_job_title),''),p_actor_id,now()) returning id into v_member;
  -- No otorga permisos generales. El rol se asigna al agregarlo a un proyecto.
  return v_member;
end; $$;
revoke all on function public.nexo_attach_registered_user(uuid,uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.nexo_attach_registered_user(uuid,uuid,uuid,text) to service_role;

-- Impide asignar tareas mediante llamadas directas a la API a miembros ajenos.
create or replace function private.validate_task_project_member()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.tasks t join public.project_members pm on pm.project_id=t.project_id
      join public.organization_members m on m.id=pm.member_id join public.projects p on p.id=t.project_id
    where t.id=new.task_id and pm.member_id=new.member_id and pm.left_at is null
      and m.status='active' and m.organization_id=p.organization_id and t.deleted_at is null
  ) then raise exception 'Solo puedes asignar tareas a miembros activos del proyecto.'; end if;
  return new;
end; $$;
drop trigger if exists validate_task_project_member on public.task_assignees;
create trigger validate_task_project_member before insert or update on public.task_assignees for each row execute function private.validate_task_project_member();

create or replace function public.nexo_team_command(p_command text,p_payload jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_project public.projects%rowtype;
  v_task public.tasks%rowtype;
  v_member public.organization_members%rowtype;
  v_role public.roles%rowtype;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null for update;
  if not found or not private.can_access_project(v_project.id) then raise exception 'Proyecto no disponible.'; end if;
  select * into v_member from public.organization_members where id=(p_payload->>'member_id')::uuid and organization_id=v_project.organization_id and status='active' for update;
  if not found then raise exception 'El usuario debe ser miembro activo de la organización.'; end if;

  if p_command='project.add' then
    if not private.has_permission(v_project.organization_id,'project.manage',v_project.id,v_project.area_id) then raise exception 'No puedes administrar este equipo.'; end if;
    select * into v_role from public.roles where organization_id=v_project.organization_id and code=coalesce(nullif(p_payload->>'role_code',''),'member') and is_active;
    if not found then raise exception 'Rol inválido.'; end if;
    if v_role.code<>'member' and not private.has_permission(v_project.organization_id,'access.manage',v_project.id,v_project.area_id) then raise exception 'No tienes permiso para asignar ese rol.'; end if;
    insert into public.project_members(project_id,member_id,project_title,is_project_manager,created_by)
      values(v_project.id,v_member.id,nullif(trim(p_payload->>'project_title'),''),v_role.code='project_manager',auth.uid())
      on conflict(project_id,member_id) do update set left_at=null,project_title=excluded.project_title,is_project_manager=excluded.is_project_manager returning id into v_id;
    -- Adición de un rol concreto con alcance de este proyecto; no modifica otros accesos.
    if not exists(select 1 from public.member_role_assignments where member_id=v_member.id and role_id=v_role.id and scope_type='project' and project_id=v_project.id and valid_from<=now() and (valid_until is null or valid_until>now())) then
      insert into public.member_role_assignments(organization_id,member_id,role_id,scope_type,project_id,assigned_by)
      values(v_project.organization_id,v_member.id,v_role.id,'project',v_project.id,auth.uid());
    end if;
  elsif p_command='task.assign' then
    select * into v_task from public.tasks where id=(p_payload->>'task_id')::uuid and project_id=v_project.id and deleted_at is null for update;
    if not found or not private.has_permission(v_project.organization_id,'task.manage',v_project.id,coalesce(v_task.area_id,v_project.area_id)) then raise exception 'No puedes asignar esta tarea.'; end if;
    if not exists(select 1 from public.project_members where project_id=v_project.id and member_id=v_member.id and left_at is null) then raise exception 'Agrega primero al usuario al equipo del proyecto.'; end if;
    -- Un responsable principal; conserva colaboradores, revisores e historial.
    delete from public.task_assignees where task_id=v_task.id and assignment_type='responsible';
    insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_member.id,'responsible',auth.uid());
    v_id:=v_task.id;
  else raise exception 'Operación no disponible.';
  end if;
  return v_id;
end; $$;
revoke all on function public.nexo_team_command(text,jsonb) from public, anon;
grant execute on function public.nexo_team_command(text,jsonb) to authenticated;
commit;
