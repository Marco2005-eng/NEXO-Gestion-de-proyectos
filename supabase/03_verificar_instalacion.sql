-- Consultas de comprobación. Ejecutar en SQL Editor con el rol postgres.

-- Todas las tablas de Nexo deben mostrar rls_enabled = true.
select tablename, rowsecurity as rls_enabled
from pg_tables
where schemaname = 'public'
order by tablename;

-- Relaciones y vistas creadas.
select table_name, table_type
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- Debe mostrar project-files con public = false.
select id, name, public, file_size_limit
from storage.buckets
where id = 'project-files';

-- Debe mostrar los roles de la organización y sus permisos.
select o.name as organization, r.code as role, count(rp.permission_id) as permissions
from public.roles r
join public.organizations o on o.id = r.organization_id
left join public.role_permissions rp on rp.role_id = r.id
group by o.name, r.code
order by o.name, r.code;

-- No debería haber perfiles pendientes.
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
