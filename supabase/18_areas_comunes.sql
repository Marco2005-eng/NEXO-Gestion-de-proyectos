-- Ejecuta este archivo en SQL Editor de Supabase.
-- Añade áreas a TODAS las organizaciones existentes. Puedes ejecutarlo nuevamente.
-- «Otro» es la opción de la interfaz para registrar un nombre personalizado;
-- no es un área compartida que mezcle proyectos de especialidades diferentes.
begin;
with comunes(code,name,description) as (values
 ('TECNOLOGIA','Tecnología','Sistemas, redes, infraestructura y transformación digital.'),
 ('FINANZAS','Finanzas','Presupuestos, tesorería y planificación financiera.'),
 ('LOGISTICA','Logística','Compras, almacenes, materiales y distribución.'),
 ('INGENIERIA-CIVIL','Ingeniería civil','Obras, construcción e infraestructura física.'),
 ('RECURSOS-HUMANOS','Recursos humanos','Personal, capacitación y desarrollo del equipo.'),
 ('OPERACIONES','Operaciones','Ejecución y coordinación de procesos operativos.'),
 ('ADMINISTRACION','Administración','Gestión administrativa y servicios internos.'),
 ('COMERCIAL','Comercial y ventas','Ventas, atención al cliente y desarrollo comercial.'),
 ('MARKETING','Marketing y comunicaciones','Publicidad, comunicación y posicionamiento.'),
 ('CALIDAD-SEGURIDAD','Calidad y seguridad','Control de calidad, prevención y seguridad laboral.')
)
insert into public.areas(organization_id,code,name,description,is_active)
select o.id,c.code,c.name,c.description,true
from public.organizations o cross join comunes c
where o.deleted_at is null
and not exists (
 select 1 from public.areas a where a.organization_id=o.id
 and (a.code=c.code or translate(lower(btrim(a.name)),'áéíóúüñ','aeiouun')=translate(lower(c.name),'áéíóúüñ','aeiouun'))
)
on conflict(organization_id,code) do nothing;
commit;

-- Comprueba las áreas disponibles por organización.
select o.name as organizacion,a.name as area,a.code as codigo
from public.areas a join public.organizations o on o.id=a.organization_id
where o.deleted_at is null and a.deleted_at is null and a.is_active
order by o.name,a.name;
