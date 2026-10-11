-- Evita el ciclo RLS tasks -> task_assignees -> tasks al actualizar tareas.
begin;
create or replace function private.can_update_task(p_task_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
   select 1 from public.tasks t join public.projects p on p.id=t.project_id
   where t.id=p_task_id and t.deleted_at is null and p.deleted_at is null
   and private.can_access_project(p.id) and (
     private.has_permission(p.organization_id,'task.manage',p.id,coalesce(t.area_id,p.area_id))
     or (private.has_permission(p.organization_id,'task.update_own',p.id,coalesce(t.area_id,p.area_id))
       and exists(select 1 from public.task_assignees a join public.organization_members m on m.id=a.member_id
         where a.task_id=t.id and m.user_id=auth.uid() and m.status='active' and m.organization_id=p.organization_id))
   )
 );
$$;
revoke all on function private.can_update_task(uuid) from public,anon;
grant execute on function private.can_update_task(uuid) to authenticated;
drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks for update to authenticated
 using(private.can_update_task(id))
 with check(private.can_access_project(project_id));
commit;
