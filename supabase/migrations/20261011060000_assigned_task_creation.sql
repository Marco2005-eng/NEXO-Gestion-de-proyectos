-- Ejecutar después del SQL 15. Guarda tarea y asignación en una sola transacción.
begin;
create or replace function public.nexo_save_assigned_task(p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_task public.tasks;v_project public.projects;v_id uuid:=nullif(p_payload->>'id','')::uuid;
v_responsible uuid:=nullif(p_payload->>'responsible_member_id','')::uuid;v_reviewer uuid:=nullif(p_payload->>'reviewer_member_id','')::uuid;
v_status text:=p_payload->>'status_code';v_due timestamptz:=nullif(p_payload->>'due_at','')::timestamptz;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión.';end if;
 if v_id is not null then
 select * into v_task from public.tasks where id=v_id and deleted_at is null for update;
 if not found then raise exception 'Tarea no disponible.';end if;
 if v_task.status_code in('in_review','completed','cancelled') then raise exception 'No cambies la tarea durante su revisión o después del cierre.';end if;
 select * into v_project from public.projects where id=v_task.project_id and deleted_at is null;
 else select * into v_project from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null;
 end if;
 if v_project.id is null or not private.can_access_project(v_project.id) or not private.has_permission(v_project.organization_id,'task.manage',v_project.id,coalesce(v_task.area_id,v_project.area_id)) or (v_id is null and not private.has_permission(v_project.organization_id,'task.create',v_project.id,v_project.area_id)) then raise exception 'No tienes permiso para asignar tareas en este proyecto.';end if;
 if v_status is null or v_status not in('pending','in_progress','blocked','cancelled') or (v_id is null and v_status='cancelled') then raise exception 'Estado inicial inválido. La aprobación se realiza revisando evidencias.';end if;
 if nullif(trim(p_payload->>'title'),'') is null or length(p_payload->>'title')>200 or length(coalesce(p_payload->>'description',''))>5000 then raise exception 'Completa el título y revisa la descripción.';end if;
 if v_due is null or (v_task.planned_start_at is not null and v_due<v_task.planned_start_at) then raise exception 'Ingresa una fecha de entrega válida.';end if;
 if coalesce(p_payload->>'priority_code','') not in('low','medium','high','critical') then raise exception 'Prioridad inválida.';end if;
 if v_responsible is null or not exists(select 1 from public.project_members pm join public.organization_members m on m.id=pm.member_id where pm.project_id=v_project.id and pm.member_id=v_responsible and pm.left_at is null and m.status='active' and m.organization_id=v_project.organization_id) then raise exception 'Selecciona un responsable activo del proyecto.';end if;
 if v_reviewer is not null and (v_reviewer=v_responsible or not exists(select 1 from public.project_members pm join public.organization_members m on m.id=pm.member_id where pm.project_id=v_project.id and pm.member_id=v_reviewer and pm.left_at is null and m.status='active' and m.organization_id=v_project.organization_id) or exists(select 1 from public.task_assignees where task_id=v_id and member_id=v_reviewer and assignment_type='collaborator')) then raise exception 'El revisor adicional debe pertenecer al proyecto y ser distinto de sus ejecutores.';end if;
 if v_id is null then
 insert into public.tasks(project_id,title,description,status_code,priority_code,progress,due_at,created_by)
 values(v_project.id,trim(p_payload->>'title'),p_payload->>'description','pending',p_payload->>'priority_code',0,v_due,auth.uid()) returning id into v_id;
 end if;
 -- Conserva colaboradores existentes. Solo cambia los cargos que se editaron.
 if not exists(select 1 from public.task_assignees where task_id=v_id and member_id=v_responsible and assignment_type='responsible') then
 delete from public.task_assignees where task_id=v_id and (assignment_type='responsible' or (member_id=v_responsible and assignment_type in('collaborator','reviewer')));
 insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_id,v_responsible,'responsible',auth.uid());
 end if;
 if not exists(select 1 from public.task_assignees where task_id=v_id and member_id=v_reviewer and assignment_type='reviewer') then
 delete from public.task_assignees where task_id=v_id and assignment_type='reviewer';
 if v_reviewer is not null then insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_id,v_reviewer,'reviewer',auth.uid());end if;
 end if;
 if not exists(select 1 from public.organization_members m where m.organization_id=v_project.organization_id and m.status='active' and private.task_reviewer(v_id,m.user_id) and not private.task_worker(v_id,m.user_id)) then raise exception 'Se necesita un supervisor distinto del ejecutor. Selecciona un revisor adicional o revisa los permisos del jefe.';end if;
 update public.tasks set title=trim(p_payload->>'title'),description=p_payload->>'description',priority_code=p_payload->>'priority_code',due_at=v_due,status_code=v_status where id=v_id;
 return v_id;
end;$$;
revoke all on function public.nexo_save_assigned_task(jsonb) from public,anon;
grant execute on function public.nexo_save_assigned_task(jsonb) to authenticated;
alter table public.task_submissions add column if not exists preferred_reviewer_member_id uuid references public.organization_members(id);
create or replace function public.nexo_task_command(p_command text,p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_task public.tasks;v_project public.projects;v_delivery public.task_submissions;v_id uuid;v_member uuid;v_file jsonb;v_path text;v_progress numeric;v_confirmed numeric;v_assigned uuid;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión';end if;
 select * into v_task from public.tasks where id=(p_payload->>'task_id')::uuid and deleted_at is null for update;
 if not found then raise exception 'Tarea no disponible';end if;
 select * into v_project from public.projects where id=v_task.project_id and deleted_at is null;
 if not found or not private.can_access_project(v_project.id) then raise exception 'Proyecto no disponible';end if;
 if p_command='task.team' then
  if not private.has_permission(v_project.organization_id,'task.manage',v_project.id,coalesce(v_task.area_id,v_project.area_id)) then raise exception 'No puedes asignar el equipo de esta tarea';end if;
  if v_task.status_code in ('in_review','completed','cancelled') then raise exception 'No cambies el equipo durante la revisión o después del cierre';end if;
  v_member:=nullif(p_payload->>'responsible_member_id','')::uuid;
  if v_member is null then raise exception 'Selecciona un responsable';end if;
  if jsonb_typeof(p_payload->'collaborator_member_ids') is distinct from 'array' then raise exception 'Lista de colaboradores inválida';end if;
  delete from public.task_assignees where task_id=v_task.id and assignment_type in ('responsible','collaborator','reviewer');
  insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_member,'responsible',auth.uid());
  for v_assigned in select distinct value::uuid from jsonb_array_elements_text(p_payload->'collaborator_member_ids') loop
   if v_assigned=v_member then raise exception 'El responsable ya ejecuta la tarea';end if;
   insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_assigned,'collaborator',auth.uid());
  end loop;
  v_member:=nullif(p_payload->>'reviewer_member_id','')::uuid;
  if v_member is not null then
   if exists(select 1 from public.task_assignees where task_id=v_task.id and member_id=v_member and assignment_type in ('responsible','collaborator')) then raise exception 'El revisor debe ser distinto de quienes ejecutan la tarea';end if;
   insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_member,'reviewer',auth.uid());
  end if;
  if not exists(select 1 from public.organization_members m where m.organization_id=v_project.organization_id and m.status='active' and private.task_reviewer(v_task.id,m.user_id) and not private.task_worker(v_task.id,m.user_id)) then raise exception 'Asigna un revisor distinto del responsable y colaboradores';end if;
 elsif p_command='task.configure' then
  if not private.has_permission(v_project.organization_id,'task.manage',v_project.id,coalesce(v_task.area_id,v_project.area_id)) then raise exception 'No puedes configurar la revisión';end if;
  if v_task.status_code in ('in_review','completed') then raise exception 'No cambies los criterios durante la revisión o después de aprobar';end if;
  if length(trim(coalesce(p_payload->>'acceptance_criteria','')))>5000 then raise exception 'Los criterios son demasiado extensos';end if;
  v_member:=nullif(p_payload->>'reviewer_member_id','')::uuid;
  if v_member is not null and (not exists(select 1 from public.project_members pm join public.organization_members m on m.id=pm.member_id where pm.project_id=v_task.project_id and pm.member_id=v_member and pm.left_at is null and m.status='active') or exists(select 1 from public.task_assignees where task_id=v_task.id and member_id=v_member and assignment_type in ('responsible','collaborator'))) then raise exception 'El revisor debe pertenecer al equipo y no ejecutar esta tarea';end if;
  update public.tasks set acceptance_criteria=nullif(trim(p_payload->>'acceptance_criteria'),''),evidence_required=true where id=v_task.id;
  delete from public.task_assignees where task_id=v_task.id and assignment_type='reviewer';
  if v_member is not null then insert into public.task_assignees(task_id,member_id,assignment_type,assigned_by) values(v_task.id,v_member,'reviewer',auth.uid());end if;
 elsif p_command='task.progress' then
  if not private.task_worker(v_task.id) then raise exception 'Solo un colaborador asignado puede reportar avance';end if;
  if v_task.status_code not in ('pending','in_progress','blocked','needs_changes') then raise exception 'La tarea está en revisión o cerrada';end if;
  v_progress:=(p_payload->>'progress')::numeric;
  if v_progress is null or v_progress<0 or v_progress>99 then raise exception 'El avance debe estar entre 0 y 99; el 100 requiere aprobación';end if;
  -- Un reporte no modifica el avance validado de la tarea.
  insert into public.task_progress_entries(task_id,reported_by,progress,note) values(v_task.id,auth.uid(),v_progress,'Avance reportado por el colaborador');
 elsif p_command='task.submit' then
  v_member:=nullif(p_payload->>'preferred_reviewer_member_id','')::uuid;
  if v_member is not null and not exists(select 1 from public.organization_members m where m.id=v_member and m.organization_id=v_project.organization_id and m.status='active' and m.user_id<>auth.uid() and private.task_reviewer(v_task.id,m.user_id) and not private.task_worker(v_task.id,m.user_id)) then raise exception 'Selecciona un supervisor autorizado distinto de los ejecutores';end if;
  if not private.task_worker(v_task.id) then raise exception 'Solo un colaborador asignado puede entregar esta tarea';end if;
  if v_task.status_code not in ('pending','in_progress','blocked','needs_changes') then raise exception 'La tarea ya está en revisión o cerrada';end if;
  v_progress:=(p_payload->>'requested_progress')::numeric;
  if v_progress is null or v_progress<0 or v_progress>100 or v_progress<>trunc(v_progress) or v_progress<v_task.progress then raise exception 'Indica un avance entero entre el avance registrado y 100';end if;
  if not exists(select 1 from public.organization_members m where m.organization_id=v_project.organization_id and m.status='active' and m.user_id<>auth.uid() and private.task_reviewer(v_task.id,m.user_id) and not private.task_worker(v_task.id,m.user_id)) then raise exception 'El jefe debe asignar un revisor distinto de los ejecutores';end if;
  if jsonb_typeof(p_payload->'files') is distinct from 'array' or jsonb_array_length(p_payload->'files')>10 then raise exception 'Puedes adjuntar hasta 10 evidencias';end if;
  if jsonb_array_length(p_payload->'files')=0 then raise exception 'Esta tarea requiere al menos una evidencia';end if;
  if length(trim(coalesce(p_payload->>'summary','')))<10 or length(p_payload->>'summary')>5000 then raise exception 'Describe lo realizado (10 a 5000 caracteres)';end if;
  insert into public.task_submissions(task_id,submitted_by,summary,criteria_snapshot,requested_progress,preferred_reviewer_member_id) values(v_task.id,auth.uid(),trim(p_payload->>'summary'),coalesce(nullif(trim(v_task.acceptance_criteria),''),nullif(trim(v_task.description),''),v_task.title),v_progress,v_member) returning id into v_id;
  for v_file in select value from jsonb_array_elements(p_payload->'files') loop
   v_path:=v_file->>'path';
   if split_part(v_path,'/',1) is distinct from auth.uid()::text or split_part(v_path,'/',2) is distinct from v_task.id::text or not exists(select 1 from storage.objects where bucket_id='task-evidence' and name=v_path) then raise exception 'Evidencia no disponible o ajena a esta tarea';end if;
   if not exists(select 1 from storage.objects o where o.bucket_id='task-evidence' and o.name=v_path and o.metadata->>'mimetype'=v_file->>'mime_type' and (o.metadata->>'size')::bigint=(v_file->>'file_size')::bigint) then raise exception 'Los datos de la evidencia no coinciden con el archivo almacenado';end if;
   if (v_file->>'mime_type') not in ('image/jpeg','image/png','image/webp','application/pdf','video/mp4','video/webm') or length(coalesce(v_file->>'file_name','')) not between 1 and 250 then raise exception 'Archivo no permitido';end if;
   insert into public.task_evidence(submission_id,storage_path,file_name,mime_type,file_size) values(v_id,v_path,v_file->>'file_name',v_file->>'mime_type',(v_file->>'file_size')::bigint);
  end loop;
  update public.tasks set status_code='in_review',completed_at=null where id=v_task.id;
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url)
  select v_project.organization_id,m.user_id,'task.review','Entrega pendiente de revisión',v_task.title||case when m.id=v_member then ' · Revisión solicitada para ti' else '' end,'/tareas' from public.organization_members m where m.organization_id=v_project.organization_id and m.status='active' and m.user_id<>auth.uid() and private.task_reviewer(v_task.id,m.user_id) and not private.task_worker(v_task.id,m.user_id);
 elsif p_command='task.review' then
  if not private.task_reviewer(v_task.id) then raise exception 'No eres jefe o revisor autorizado de esta tarea';end if;
  select * into v_delivery from public.task_submissions where id=(p_payload->>'submission_id')::uuid and task_id=v_task.id for update;
  if not found or v_delivery.status<>'pending' or v_task.status_code<>'in_review' then raise exception 'Esta entrega ya fue revisada o no está pendiente';end if;
  if v_delivery.submitted_by=auth.uid() or private.task_worker(v_task.id) then raise exception 'No puedes aprobar ni revisar tu propia tarea';end if;
  if coalesce(p_payload->>'decision','') not in ('approved','needs_changes') then raise exception 'Decisión inválida';end if;
  if length(coalesce(p_payload->>'comment',''))>5000 or (p_payload->>'decision'='needs_changes' and length(trim(coalesce(p_payload->>'comment','')))<5) then raise exception 'Indica qué debe corregirse (mínimo 5 caracteres)';end if;
  if p_payload->>'decision'='approved' then
   if coalesce(p_payload->>'evidence_checked','') not in ('on','true') then raise exception 'Confirma que revisaste las fotos o archivos de la entrega';end if;
   if not exists(select 1 from public.task_evidence where submission_id=v_delivery.id) then raise exception 'Revisa una evidencia antes de aprobar el avance';end if;
   v_confirmed:=coalesce(nullif(p_payload->>'confirmed_progress','')::numeric,v_delivery.requested_progress);
   if v_confirmed<v_task.progress or v_confirmed>v_delivery.requested_progress or v_confirmed<>trunc(v_confirmed) then raise exception 'El avance confirmado debe estar entre el avance registrado y el porcentaje solicitado';end if;
   if v_confirmed<v_delivery.requested_progress and length(trim(coalesce(p_payload->>'comment','')))<5 then raise exception 'Explica por qué confirmas un porcentaje menor';end if;
  end if;
  update public.task_submissions set status=p_payload->>'decision',reviewed_by=auth.uid(),reviewed_at=now(),review_comment=nullif(trim(p_payload->>'comment'),''),evidence_checked=coalesce(p_payload->>'evidence_checked','') in ('on','true'),confirmed_progress=case when p_payload->>'decision'='approved' then v_confirmed else null end where id=v_delivery.id;
  update public.tasks set status_code=case when p_payload->>'decision'='approved' then case when v_confirmed=100 then 'completed' else 'in_progress' end else 'needs_changes' end,progress=case when p_payload->>'decision'='approved' then v_confirmed else progress end,completed_at=case when p_payload->>'decision'='approved' and v_confirmed=100 then now() else null end where id=v_task.id;
  insert into public.notifications(organization_id,recipient_user_id,notification_type,title,body,action_url) values(v_project.organization_id,v_delivery.submitted_by,'task.reviewed',case when p_payload->>'decision'='approved' then case when v_confirmed=100 then 'Tarea aprobada' else 'Avance validado' end else 'Entrega por corregir' end,v_task.title,'/tareas');v_id:=v_delivery.id;
 else raise exception 'Operación inválida';end if;
 return coalesce(v_id,v_task.id);
end $$;
revoke all on function public.nexo_task_command(text,jsonb) from public,anon;
grant execute on function public.nexo_task_command(text,jsonb) to authenticated;

create or replace function private.guard_task_review() returns trigger language plpgsql security definer set search_path='' as $$
declare v_manager boolean;
begin
 if auth.uid() is null then return new;end if;
 if new.status_code='completed' and (tg_op='INSERT' or old.status_code<>'completed') and not exists(select 1 from public.task_submissions where task_id=new.id and status='approved' and confirmed_progress=100) then raise exception 'Completar una tarea requiere una entrega aprobada';end if;
 if new.status_code='in_review' and (tg_op='INSERT' or old.status_code<>'in_review') and not exists(select 1 from public.task_submissions where task_id=new.id and status='pending') then raise exception 'Usa Enviar a revisión con una entrega y evidencias';end if;
 if new.status_code='needs_changes' and (tg_op='INSERT' or old.status_code<>'needs_changes') and not exists(select 1 from public.task_submissions where task_id=new.id and status='needs_changes' and reviewed_at>=transaction_timestamp()) then raise exception 'Solicita correcciones desde la revisión de una entrega';end if;
 if new.status_code='completed' and new.progress<>100 then raise exception 'Una tarea completada tiene 100 %% de avance';end if;
 if new.progress=100 and new.status_code<>'completed' then raise exception 'El 100 %% se registra al aprobar la entrega';end if;
 if tg_op='UPDATE' then
  if new.progress is distinct from old.progress and not exists(select 1 from public.task_submissions where task_id=new.id and status='approved' and reviewed_by=auth.uid() and reviewed_at>=transaction_timestamp() and confirmed_progress=new.progress) then raise exception 'El avance solo cambia con una revisión aprobada de sus evidencias';end if;
  if old.status_code='in_review' and new.status_code<>'in_review' and exists(select 1 from public.task_submissions where task_id=new.id and status='pending') then raise exception 'Debes aprobar la entrega o solicitar correcciones';end if;
  if old.status_code='completed' and (to_jsonb(new)-'updated_at') is distinct from (to_jsonb(old)-'updated_at') then raise exception 'La tarea aprobada está cerrada';end if;
  if old.status_code='in_review' and new.status_code='in_review' and (to_jsonb(new)-'updated_at') is distinct from (to_jsonb(old)-'updated_at') then raise exception 'La tarea está en revisión; registra una decisión antes de modificarla';end if;
  if (new.acceptance_criteria is distinct from old.acceptance_criteria or new.evidence_required is distinct from old.evidence_required) and old.status_code in ('in_review','completed') then raise exception 'Los criterios de la entrega no se pueden cambiar';end if;
  select private.has_permission(p.organization_id,'task.manage',p.id,coalesce(old.area_id,p.area_id)) into v_manager from public.projects p where p.id=old.project_id;
  if not v_manager then
   if exists(select 1 from public.task_submissions where task_id=new.id and reviewed_by=auth.uid() and reviewed_at>=transaction_timestamp() and status in ('approved','needs_changes')) then
    if (to_jsonb(new)-array['progress','status_code','completed_at','updated_at']) is distinct from (to_jsonb(old)-array['progress','status_code','completed_at','updated_at']) then raise exception 'El revisor solo puede registrar su decisión';end if;
   elsif not private.task_worker(new.id) or (new.status_code is distinct from old.status_code and new.status_code not in ('in_progress','in_review')) or old.status_code not in ('pending','in_progress','blocked','needs_changes') or (to_jsonb(new)-array['status_code','updated_at']) is distinct from (to_jsonb(old)-array['status_code','updated_at']) then raise exception 'El colaborador solo puede reportar su avance';end if;
  end if;
 end if;return new;
end $$;

-- Los cargos por sí solos no dan permiso: revisan el jefe autorizado o el revisor asignado.

commit;
