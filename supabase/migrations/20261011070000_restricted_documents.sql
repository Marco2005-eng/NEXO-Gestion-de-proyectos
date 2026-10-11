-- Documentos privados con destinatarios y versiones. Ejecutar después de 01–16.
begin;
create table if not exists public.document_library (
 id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 project_id uuid not null references public.projects(id), title text not null, description text not null default '',
 created_by uuid not null references public.profiles(id), recipient_ids uuid[] not null default '{}', area_id uuid references public.areas(id),
 material_approvers boolean not null default false, corrections_enabled boolean not null default false,
 status text not null default 'pending' check(status in ('pending','needs_changes','approved')),
 review_note text not null default '', reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.document_versions (
 id uuid primary key default extensions.gen_random_uuid(), document_id uuid not null references public.document_library(id),
 version integer not null check(version>0), storage_path text not null unique, file_name text not null,
 mime_type text not null, size_bytes bigint not null check(size_bytes>0 and size_bytes<=20971520),
 note text not null default '', uploaded_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
 unique(document_id,version)
);
create or replace function private.document_manage(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.document_library d where d.id=p_id and (
 private.is_platform_admin() or (private.can_access_project(d.project_id) and (
 d.created_by=auth.uid() or private.has_permission(d.organization_id,'organization.manage') or exists(
 select 1 from public.project_members pm join public.organization_members m on m.id=pm.member_id
 where pm.project_id=d.project_id and pm.is_project_manager and pm.left_at is null and m.user_id=auth.uid() and m.status='active')))));
$$;
create or replace function private.document_read(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.document_manage(p_id) or exists(select 1 from public.document_library d where d.id=p_id
 and private.can_access_project(d.project_id) and exists(select 1 from public.organization_members m
 where m.organization_id=d.organization_id and m.status='active' and m.user_id=auth.uid() and (
 m.id=any(d.recipient_ids) or (d.material_approvers and (private.has_permission(d.organization_id,'material.approve',d.project_id) or private.has_permission(d.organization_id,'approval.decide',d.project_id)))
 or (d.area_id is not null and exists(select 1 from public.member_role_assignments a join public.roles r on r.id=a.role_id
 where a.member_id=m.id and a.area_id=d.area_id and a.scope_type='area' and a.valid_from<=now() and (a.valid_until is null or a.valid_until>now()) and r.is_active)) )));
$$;
create or replace function private.document_review(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.document_manage(p_id) or exists(select 1 from public.document_library d where d.id=p_id and private.document_read(d.id)
 and (private.has_permission(d.organization_id,'material.approve',d.project_id) or private.has_permission(d.organization_id,'approval.decide',d.project_id)));
$$;
create or replace function private.document_upload(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.document_manage(p_id) or exists(select 1 from public.document_library d where d.id=p_id and d.corrections_enabled and private.document_read(d.id));
$$;
alter table public.document_library enable row level security;
alter table public.document_versions enable row level security;
drop policy if exists document_library_read on public.document_library;
create policy document_library_read on public.document_library for select to authenticated using(private.document_read(id));
drop policy if exists document_versions_read on public.document_versions;
create policy document_versions_read on public.document_versions for select to authenticated using(private.document_read(document_id));
grant select on public.document_library,public.document_versions to authenticated;
revoke insert,update,delete on public.document_library,public.document_versions from authenticated,anon;

create or replace function public.nexo_document_command(p_command text,p_payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid:=(p_payload->>'id')::uuid; d public.document_library; p public.projects; v_ids uuid[]; v_area uuid;
 v_path text; v_version integer; v_object storage.objects; v_size bigint; v_mime text;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 if p_command='create' then
  select * into p from public.projects where id=(p_payload->>'project_id')::uuid and deleted_at is null;
  if p.id is null or not private.can_access_project(p.id) or not private.has_permission(p.organization_id,'document.manage',p.id) then raise exception 'No puedes cargar documentos en este proyecto'; end if;
  if length(btrim(coalesce(p_payload->>'title','')))=0 then raise exception 'Escribe el título'; end if;
  select coalesce(array_agg(x::uuid),'{}'::uuid[]) into v_ids from jsonb_array_elements_text(coalesce(p_payload->'recipient_ids','[]')) x;
  v_area:=nullif(p_payload->>'area_id','')::uuid;
  if exists(select 1 from unnest(v_ids) i where not exists(select 1 from public.organization_members m where m.id=i and m.organization_id=p.organization_id and m.status='active' and private.can_access_project(p.id,m.user_id))) then raise exception 'Los destinatarios deben tener acceso al proyecto'; end if;
  if v_area is not null and not exists(select 1 from public.areas where id=v_area and organization_id=p.organization_id and deleted_at is null) then raise exception 'Área inválida'; end if;
  insert into public.document_library(id,organization_id,project_id,title,description,created_by,recipient_ids,area_id,material_approvers,corrections_enabled)
  values(v_id,p.organization_id,p.id,btrim(p_payload->>'title'),coalesce(p_payload->>'description',''),auth.uid(),v_ids,v_area,coalesce((p_payload->>'material_approvers')::boolean,false),coalesce((p_payload->>'corrections_enabled')::boolean,false));
 elsif p_command='version' then
  if not private.document_upload(v_id) then raise exception 'La carga de correcciones no está habilitada para tu cuenta'; end if;
 elsif p_command in ('review','enable') then
  select * into d from public.document_library where id=v_id for update;
  if not private.document_review(v_id) then raise exception 'No puedes revisar este documento'; end if;
  if p_command='enable' then
   if not private.document_manage(v_id) then raise exception 'Solo el responsable puede habilitar nuevas versiones'; end if;
   update public.document_library set corrections_enabled=(p_payload->>'enabled')::boolean where id=v_id;
  else
   if p_payload->>'status' not in ('approved','needs_changes') then raise exception 'Decisión inválida'; end if;
   if p_payload->>'status'='needs_changes' and length(btrim(coalesce(p_payload->>'note','')))=0 then raise exception 'Explica qué debe corregirse'; end if;
   if (p_payload->>'version')::integer is distinct from (select max(version) from public.document_versions where document_id=v_id) then raise exception 'Hay una nueva versión. Actualiza antes de revisar'; end if;
   update public.document_library set status=p_payload->>'status',review_note=coalesce(p_payload->>'note',''),reviewed_by=auth.uid(),reviewed_at=now(),corrections_enabled=(p_payload->>'status'='needs_changes') where id=v_id;
  end if;
  return v_id;
 else raise exception 'Operación inválida'; end if;
 select * into d from public.document_library where id=v_id for update;
 v_path:=p_payload->>'storage_path';
 if split_part(v_path,'/',1)<>d.organization_id::text or split_part(v_path,'/',2)<>d.project_id::text or split_part(v_path,'/',3)<>d.id::text or split_part(v_path,'/',4)<>auth.uid()::text then raise exception 'Ruta de archivo inválida'; end if;
 select * into v_object from storage.objects where bucket_id='restricted-documents' and name=v_path;
 if v_object.id is null then raise exception 'Primero carga el archivo'; end if;
 v_size:=(v_object.metadata->>'size')::bigint; v_mime:=v_object.metadata->>'mimetype';
 if v_mime is null or v_size is null or v_size<=0 or v_size>20971520 or v_mime not in ('application/pdf','image/jpeg','image/png','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/plain') then raise exception 'Archivo no admitido: PDF, Word, Excel, JPG, PNG o TXT, máximo 20 MB'; end if;
 select coalesce(max(version),0)+1 into v_version from public.document_versions where document_id=v_id;
 insert into public.document_versions(document_id,version,storage_path,file_name,mime_type,size_bytes,note,uploaded_by)
 values(v_id,v_version,v_path,left(p_payload->>'file_name',255),v_mime,v_size,coalesce(p_payload->>'note',''),auth.uid());
 update public.document_library set status='pending',corrections_enabled=false,review_note='',reviewed_by=null,reviewed_at=null where id=v_id;
 return v_id;
end; $$;
create or replace function public.nexo_documents(p_organization_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(d)||jsonb_build_object('can_manage',private.document_manage(d.id),'can_review',private.document_review(d.id),'can_upload',private.document_upload(d.id),'versions',(select coalesce(jsonb_agg(to_jsonb(v)-'storage_path' order by version desc),'[]'::jsonb) from public.document_versions v where v.document_id=d.id)) order by d.created_at desc),'[]'::jsonb)
 from public.document_library d where d.organization_id=p_organization_id and private.document_read(d.id);
$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('restricted-documents','restricted-documents',false,20971520,array['application/pdf','image/jpeg','image/png','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/plain']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists restricted_documents_read on storage.objects;
create policy restricted_documents_read on storage.objects for select to authenticated using(bucket_id='restricted-documents' and (exists(select 1 from public.document_versions v where v.storage_path=name and private.document_read(v.document_id)) or ((storage.foldername(storage.objects.name))[4]=auth.uid()::text and not exists(select 1 from public.document_versions v where v.storage_path=name))));
drop policy if exists restricted_documents_insert on storage.objects;
create policy restricted_documents_insert on storage.objects for insert to authenticated with check(bucket_id='restricted-documents' and (storage.foldername(storage.objects.name))[4]=auth.uid()::text and exists(select 1 from public.projects p where p.id::text=(storage.foldername(storage.objects.name))[2] and p.organization_id::text=(storage.foldername(storage.objects.name))[1] and p.deleted_at is null and private.can_access_project(p.id) and (
 (not exists(select 1 from public.document_library d where d.id::text=(storage.foldername(storage.objects.name))[3]) and private.has_permission(p.organization_id,'document.manage',p.id)) or exists(select 1 from public.document_library d where d.id::text=(storage.foldername(storage.objects.name))[3] and d.project_id=p.id and private.document_upload(d.id)))));
drop policy if exists restricted_documents_cleanup on storage.objects;
create policy restricted_documents_cleanup on storage.objects for delete to authenticated using(bucket_id='restricted-documents' and (storage.foldername(storage.objects.name))[4]=auth.uid()::text and not exists(select 1 from public.document_versions v where v.storage_path=name));
revoke all on function public.nexo_document_command(text,jsonb),public.nexo_documents(uuid) from public,anon;
grant execute on function public.nexo_document_command(text,jsonb),public.nexo_documents(uuid) to authenticated;
revoke all on function private.document_manage(uuid),private.document_read(uuid),private.document_review(uuid),private.document_upload(uuid) from public,anon;
grant execute on function private.document_manage(uuid),private.document_read(uuid),private.document_review(uuid),private.document_upload(uuid) to authenticated;
commit;


