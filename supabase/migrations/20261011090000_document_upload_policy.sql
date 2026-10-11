-- Ejecutar después de 17_documentos_restringidos.sql.
-- Evita que «name» dentro de la política se interprete como el nombre del proyecto.
begin;
create or replace function private.document_storage_upload(p_path text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare parts text[]:=string_to_array(p_path,'/'); v_org uuid; v_project uuid; v_document uuid; d public.document_library;
begin
 if auth.uid() is null or array_length(parts,1)<>5 or parts[4]<>auth.uid()::text then return false; end if;
 begin
  v_org:=parts[1]::uuid;v_project:=parts[2]::uuid;v_document:=parts[3]::uuid;
 exception when invalid_text_representation then return false;
 end;
 if not exists(select 1 from public.projects p where p.id=v_project and p.organization_id=v_org and p.deleted_at is null)
 or not private.can_access_project(v_project) then return false; end if;
 select * into d from public.document_library where id=v_document;
 if found then
  return d.organization_id=v_org and d.project_id=v_project and private.document_upload(v_document);
 end if;
 return private.has_permission(v_org,'document.manage',v_project);
end; $$;
revoke all on function private.document_storage_upload(text) from public,anon;
grant execute on function private.document_storage_upload(text) to authenticated;
drop policy if exists restricted_documents_insert on storage.objects;
create policy restricted_documents_insert on storage.objects for insert to authenticated
with check(bucket_id='restricted-documents' and private.document_storage_upload(storage.objects.name));
commit;
