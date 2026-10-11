-- Entregas, evidencias privadas y revisión de tareas. Instalar después del SQL 11.
begin;
insert into public.task_statuses(code,name,display_order,is_terminal,color) values('needs_changes','Por corregir',35,false,'orange') on conflict(code) do nothing;
alter table public.tasks add column if not exists evidence_required boolean not null default true;
create table if not exists public.task_submissions(
 id uuid primary key default extensions.gen_random_uuid(),task_id uuid not null references public.tasks(id),
 submitted_by uuid not null references public.profiles(id),summary text not null check(length(trim(summary)) between 10 and 5000),
 criteria_snapshot text,status text not null default 'pending' check(status in ('pending','approved','needs_changes')),
 submitted_at timestamptz not null default now(),reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_comment text
);
create unique index if not exists task_one_pending_delivery on public.task_submissions(task_id) where status='pending';
create table if not exists public.task_evidence(
 id uuid primary key default extensions.gen_random_uuid(),submission_id uuid not null references public.task_submissions(id),
 storage_path text not null unique,file_name text not null,mime_type text not null,file_size bigint not null check(file_size between 1 and 52428800)
);
create or replace function private.task_worker(p_task uuid,p_user uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.tasks t join public.task_assignees a on a.task_id=t.id join public.organization_members m on m.id=a.member_id join public.project_members pm on pm.project_id=t.project_id and pm.member_id=m.id
 where t.id=p_task and t.deleted_at is null and m.user_id=p_user and m.status='active' and pm.left_at is null and a.assignment_type in ('responsible','collaborator'));
$$;
create or replace function private.task_reviewer(p_task uuid,p_user uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.tasks t join public.projects p on p.id=t.project_id where t.id=p_task and t.deleted_at is null and (
 private.has_permission(p.organization_id,'task.manage',p.id,coalesce(t.area_id,p.area_id),p_user) or exists(
 select 1 from public.task_assignees a join public.organization_members m on m.id=a.member_id join public.project_members pm on pm.project_id=t.project_id and pm.member_id=m.id
 where a.task_id=t.id and a.assignment_type='reviewer' and m.user_id=p_user and m.status='active' and pm.left_at is null)));
$$;
create or replace function private.task_delivery_reader(p_task uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.tasks t join public.projects p on p.id=t.project_id where t.id=p_task and t.deleted_at is null and private.can_access_project(p.id)
 and (private.task_worker(t.id) or private.task_reviewer(t.id) or private.has_permission(p.organization_id,'audit.view',p.id,coalesce(t.area_id,p.area_id))));
$$;
revoke all on function private.task_worker(uuid,uuid),private.task_reviewer(uuid,uuid),private.task_delivery_reader(uuid) from public,anon;
grant execute on function private.task_worker(uuid,uuid),private.task_reviewer(uuid,uuid),private.task_delivery_reader(uuid) to authenticated;
alter table public.task_submissions enable row level security;
alter table public.task_evidence enable row level security;
drop policy if exists deliveries_read on public.task_submissions;
create policy deliveries_read on public.task_submissions for select to authenticated using(private.task_delivery_reader(task_id));
drop policy if exists evidence_read on public.task_evidence;
create policy evidence_read on public.task_evidence for select to authenticated using(exists(select 1 from public.task_submissions s where s.id=submission_id and private.task_delivery_reader(s.task_id)));
grant select on public.task_submissions,public.task_evidence to authenticated;
revoke insert,update,delete on public.task_submissions,public.task_evidence from authenticated,anon;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('task-evidence','task-evidence',false,52428800,array['image/jpeg','image/png','image/webp','application/pdf','video/mp4','video/webm'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create or replace function private.evidence_upload_allowed(p_path text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_task uuid;
begin
 if split_part(p_path,'/',1) is distinct from auth.uid()::text then return false; end if;
 begin v_task:=split_part(p_path,'/',2)::uuid;exception when invalid_text_representation then return false;end;
 return private.task_worker(v_task) and exists(select 1 from public.tasks where id=v_task and status_code in ('pending','in_progress','blocked','needs_changes'));
end $$;
create or replace function private.evidence_read_allowed(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select private.evidence_upload_allowed(p_path) or exists(select 1 from public.task_evidence e join public.task_submissions s on s.id=e.submission_id where e.storage_path=p_path and private.task_delivery_reader(s.task_id));
$$;
revoke all on function private.evidence_upload_allowed(text),private.evidence_read_allowed(text) from public,anon;
grant execute on function private.evidence_upload_allowed(text),private.evidence_read_allowed(text) to authenticated;
drop policy if exists task_evidence_upload on storage.objects;
create policy task_evidence_upload on storage.objects for insert to authenticated with check(bucket_id='task-evidence' and private.evidence_upload_allowed(name));
drop policy if exists task_evidence_read on storage.objects;
create policy task_evidence_read on storage.objects for select to authenticated using(bucket_id='task-evidence' and private.evidence_read_allowed(name));
-- Sin UPDATE ni DELETE: una evidencia entregada conserva su contenido.

create or replace function public.nexo_task_command(p_command text,p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_task public.tasks;v_project public.projects;v_delivery public.task_submissions;v_id uuid;v_member uuid;v_file jsonb;v_path text;v_progress numeric;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión';end if;
 select * into v_task from public.tasks where id=(p_payload->>'task_id')::uuid and deleted_at is null for update;
 if not found then raise exception 'Tarea no disponible';end if;
 select * into v_project from public.projects where id=v_task.project_id and deleted_at is null;
 if not found or not private.can_access_project(v_project.id) then raise exception 'Proyecto no disponible';end if;
 if p_command='task.configure' then
  if not private.has_permission(v_project.organization_id,'task.manage',v_project.id,coalesce(v_task.area_id,v_project.area_id)) then raise exception 'No puedes configurar la revisión';end if;
  if v_task.status_code in ('in_review','completed') then raise exception 'No cambies los criterios durante la revisión o después de aprobar';end if;
  if length(trim(coalesce(p_payload->>'acceptance_criteria','')))>5000 then raise exception 'Los criterios son demasiado extensos';end if;
  v_member:=nullif(p_payload->>'reviewer_member_id','')::uuid;
  if v_member is not null and (not exists(select 1 from public.project_members pm join public.organization_members m on m.id=pm.member_id where pm.project_id=v_task.project_id and pm.member_id=v_member and pm.left_at is null and m.status='active') or exists(select 1 from public.task_assignees where task_id=v_task.id and member_id=v_member and assignment_type in ('responsible','collaborator'))) then raise exception 'El revisor debe pertenecer al equipo y no ejecutar esta tarea';end if;
  update public.tasks set acceptance_criteria=nullif(trim(p_payload->>'acceptance_criteria'),''),evidence_required=coalesce((p_payload->>'evidence_required')::boolean,true) where id=v_task.id;
  delete from public.task_assignees where task_id=v_task.id and assignment_type='reviewer';
  if v_member is not null then insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_member,'reviewer',auth.uid());end if;
 elsif p_command='task.progress' then
  if not private.task_worker(v_task.id) then raise exception 'Solo un colaborador asignado puede reportar avance';end if;
  if v_task.status_code not in ('pending','in_progress','blocked','needs_changes') then raise exception 'La tarea está en revisión o cerrada';end if;
  v_progress:=(p_payload->>'progress')::numeric;
  if v_progress is null or v_progress<0 or v_progress>99 then raise exception 'El avance debe estar entre 0 y 99; el 100 requiere aprobación';end if;
  update public.tasks set progress=v_progress,status_code='in_progress' where id=v_task.id;
  insert into public.task_progress_entries(task_id,reported_by,progress,note) values(v_task.id,auth.uid(),v_progress,'Avance reportado por el colaborador');
 elsif p_command='task.submit' then
  if not private.task_worker(v_task.id) then raise exception 'Solo un colaborador asignado puede entregar esta tarea';end if;
  if v_task.status_code not in ('pending','in_progress','blocked','needs_changes') then raise exception 'La tarea ya está en revisión o cerrada';end if;
  if nullif(trim(v_task.acceptance_criteria),'') is null then raise exception 'El jefe debe definir los criterios de aceptación antes de la entrega';end if;
  if jsonb_typeof(p_payload->'files') is distinct from 'array' or jsonb_array_length(p_payload->'files')>10 then raise exception 'Puedes adjuntar hasta 10 evidencias';end if;
  if v_task.evidence_required and jsonb_array_length(p_payload->'files')=0 then raise exception 'Esta tarea requiere al menos una evidencia';end if;
  if length(trim(coalesce(p_payload->>'summary','')))<10 or length(p_payload->>'summary')>5000 then raise exception 'Describe lo realizado (10 a 5000 caracteres)';end if;
  insert into public.task_submissions(task_id,submitted_by,summary,criteria_snapshot) values(v_task.id,auth.uid(),trim(p_payload->>'summary'),v_task.acceptance_criteria) returning id into v_id;
  for v_file in select value from jsonb_array_elements(p_payload->'files') loop
   v_path:=v_file->>'path';
   if split_part(v_path,'/',1) is distinct from auth.uid()::text or split_part(v_path,'/',2) is distinct from v_task.id::text or not exists(select 1 from storage.objects where bucket_id='task-evidence' and name=v_path) then raise exception 'Evidencia no disponible o ajena a esta tarea';end if;
   if not exists(select 1 from storage.objects o where o.bucket_id='task-evidence' and o.name=v_path and o.metadata->>'mimetype'=v_file->>'mime_type' and (o.metadata->>'size')::bigint=(v_file->>'file_size')::bigint) then raise exception 'Los datos de la evidencia no coinciden con el archivo almacenado';end if;
   if (v_file->>'mime_type') not in ('image/jpeg','image/png','image/webp','application/pdf','video/mp4','video/webm') or length(coalesce(v_file->>'file_name','')) not between 1 and 250 then raise exception 'Archivo no permitido';end if;
   insert into public.task_evidence(submission_id,storage_path,file_name,mime_type,file_size) values(v_id,v_path,v_file->>'file_name',v_file->>'mime_type',(v_file->>'file_size')::bigint);
  end loop;
  update public.tasks set status_code='in_review',completed_at=null where id=v_task.id;
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
  select v_project.organization_id,m.user_id,'task.review','Entrega pendiente de revisión',v_task.title,'/tareas' from public.organization_members m where m.organization_id=v_project.organization_id and m.status='active' and m.user_id<>auth.uid() and private.task_reviewer(v_task.id,m.user_id);
 elsif p_command='task.review' then
  if not private.task_reviewer(v_task.id) then raise exception 'No eres jefe o revisor autorizado de esta tarea';end if;
  select * into v_delivery from public.task_submissions where id=(p_payload->>'submission_id')::uuid and task_id=v_task.id for update;
  if not found or v_delivery.status<>'pending' or v_task.status_code<>'in_review' then raise exception 'Esta entrega ya fue revisada o no está pendiente';end if;
  if v_delivery.submitted_by=auth.uid() or private.task_worker(v_task.id) then raise exception 'No puedes aprobar ni revisar tu propia tarea';end if;
  if coalesce(p_payload->>'decision','') not in ('approved','needs_changes') then raise exception 'Decisión inválida';end if;
  if length(coalesce(p_payload->>'comment',''))>5000 or (p_payload->>'decision'='needs_changes' and length(trim(coalesce(p_payload->>'comment','')))<5) then raise exception 'Indica qué debe corregirse (mínimo 5 caracteres)';end if;
  update public.task_submissions set status=p_payload->>'decision',reviewed_by=auth.uid(),reviewed_at=now(),review_comment=nullif(trim(p_payload->>'comment'),'') where id=v_delivery.id;
  update public.tasks set status_code=case when p_payload->>'decision'='approved' then 'completed' else 'needs_changes' end,progress=case when p_payload->>'decision'='approved' then 100 else least(progress,99) end,completed_at=case when p_payload->>'decision'='approved' then now() else null end where id=v_task.id;
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url) values(v_project.organization_id,v_delivery.submitted_by,'task.reviewed',case when p_payload->>'decision'='approved' then 'Tarea aprobada' else 'Entrega por corregir' end,v_task.title,'/tareas');v_id:=v_delivery.id;
 else raise exception 'Operación inválida';end if;
 return coalesce(v_id,v_task.id);
end $$;
revoke all on function public.nexo_task_command(text,jsonb) from public,anon;
grant execute on function public.nexo_task_command(text,jsonb) to authenticated;

create or replace function private.guard_task_review() returns trigger language plpgsql security definer set search_path='' as $$
declare v_manager boolean;
begin
 if auth.uid() is null then return new;end if;
 if new.status_code='completed' and (tg_op='INSERT' or old.status_code<>'completed') and not exists(select 1 from public.task_submissions where task_id=new.id and status='approved') then raise exception 'Completar una tarea requiere una entrega aprobada';end if;
 if new.status_code='in_review' and (tg_op='INSERT' or old.status_code<>'in_review') and not exists(select 1 from public.task_submissions where task_id=new.id and status='pending') then raise exception 'Usa Enviar a revisión con una entrega y evidencias';end if;
 if new.status_code='needs_changes' and (tg_op='INSERT' or old.status_code<>'needs_changes') and not exists(select 1 from public.task_submissions where task_id=new.id and status='needs_changes' and reviewed_at>=transaction_timestamp()) then raise exception 'Solicita correcciones desde la revisión de una entrega';end if;
 if new.status_code='completed' and new.progress<>100 then raise exception 'Una tarea completada tiene 100 %% de avance';end if;
 if new.progress=100 and new.status_code<>'completed' then raise exception 'El 100 %% se registra al aprobar la entrega';end if;
 if tg_op='UPDATE' then
  if old.status_code='in_review' and new.status_code<>'in_review' and exists(select 1 from public.task_submissions where task_id=new.id and status='pending') then raise exception 'Debes aprobar la entrega o solicitar correcciones';end if;
  if old.status_code='completed' and (to_jsonb(new)-'updated_at') is distinct from (to_jsonb(old)-'updated_at') then raise exception 'La tarea aprobada está cerrada';end if;
  if old.status_code='in_review' and new.status_code='in_review' and (to_jsonb(new)-'updated_at') is distinct from (to_jsonb(old)-'updated_at') then raise exception 'La tarea está en revisión; registra una decisión antes de modificarla';end if;
  if (new.acceptance_criteria is distinct from old.acceptance_criteria or new.evidence_required is distinct from old.evidence_required) and old.status_code in ('in_review','completed') then raise exception 'Los criterios de la entrega no se pueden cambiar';end if;
  select private.has_permission(p.organization_id,'task.manage',p.id,coalesce(old.area_id,p.area_id)) into v_manager from public.projects p where p.id=old.project_id;
  if not v_manager then
   if exists(select 1 from public.task_submissions where task_id=new.id and reviewed_by=auth.uid() and reviewed_at>=transaction_timestamp() and status in ('approved','needs_changes')) then
    if (to_jsonb(new)-array['progress','status_code','completed_at','updated_at']) is distinct from (to_jsonb(old)-array['progress','status_code','completed_at','updated_at']) then raise exception 'El revisor solo puede registrar su decisión';end if;
   elsif not private.task_worker(new.id) or (new.status_code is distinct from old.status_code and new.status_code not in ('in_progress','in_review')) or old.status_code not in ('pending','in_progress','blocked','needs_changes') or (to_jsonb(new)-array['progress','status_code','updated_at']) is distinct from (to_jsonb(old)-array['progress','status_code','updated_at']) then raise exception 'El colaborador solo puede reportar su avance';end if;
  end if;
 end if;return new;
end $$;
drop trigger if exists guard_task_review on public.tasks;
create trigger guard_task_review before insert or update on public.tasks for each row execute function private.guard_task_review();
commit;
