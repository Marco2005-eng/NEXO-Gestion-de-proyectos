-- Ejecutar en SQL Editor DESPUÉS de 01_instalar_nexo.sql.
-- Primero crear un usuario con contraseña en Authentication > Users.
-- Reemplazar el correo de ejemplo por el correo de ese usuario.
-- Este script no crea contraseñas ni modifica auth.users.

begin;

do $$
declare
  v_email text := '2023100659@ucss.pe';
  v_name text := 'Mi organización';
  v_slug text := 'mi-organizacion';
  v_user_id uuid;
  v_org_id uuid;
begin
  if nullif(trim(v_email), '') is null or position('@' in v_email) = 0 then
    raise exception 'Escribe en v_email el correo del usuario creado en Authentication > Users.';
  end if;

  select id into v_user_id from auth.users where lower(email) = lower(trim(v_email));
  if v_user_id is null then
    raise exception 'No existe el usuario %. Créalo primero en Authentication > Users.', v_email;
  end if;
  if not exists (select 1 from public.profiles where id = v_user_id) then
    raise exception 'El usuario no tiene perfil. Comprueba que ejecutaste 01_instalar_nexo.sql.';
  end if;

  select id into v_org_id from public.organizations where slug = v_slug and deleted_at is null;
  if v_org_id is not null then
    if not exists (
      select 1
      from public.organization_members m
      join public.member_role_assignments a on a.member_id = m.id
      join public.roles r on r.id = a.role_id
      where m.organization_id = v_org_id and m.user_id = v_user_id
        and r.organization_id = v_org_id and r.code = 'admin'
        and a.scope_type = 'organization'
    ) then
      raise exception 'El slug % ya pertenece a una organización existente. Usa otro slug para crear una nueva.', v_slug;
    end if;
    raise notice 'La organización % y el administrador ya existen. ID: %', v_slug, v_org_id;
  else
    v_org_id := private.bootstrap_organization(v_name, v_slug, v_user_id);
    raise notice 'Organización creada. ID: %. Administrador: %', v_org_id, v_email;
  end if;
end;
$$;

commit;

-- Resultado: organización, siete roles, permisos por rol y administrador inicial.
select o.id as organization_id, o.name as organization_name, o.slug,
       p.display_name as administrator, u.email
from public.organizations o
join public.organization_members m on m.organization_id = o.id
join public.profiles p on p.id = m.user_id
join auth.users u on u.id = p.id
join public.member_role_assignments a on a.member_id = m.id
join public.roles r on r.id = a.role_id
where r.code = 'admin' and a.scope_type = 'organization';
