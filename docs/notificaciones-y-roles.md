# Notificaciones y roles

## Activación en Supabase

Después de instalar los SQL 01, 05 y 06, ejecuta el contenido completo de
`supabase/07_notificaciones_roles.sql` en SQL Editor. No elimina los datos existentes.
Recarga Nexo. No hace falta agregar variables al `.env.local` para estas funciones.

## Roles

En Administración → Roles y permisos puedes consultar los roles del sistema,
crear roles personalizados con permisos seleccionados y editar esos permisos.
El administrador puede asignar roles a miembros activos con alcance de organización,
área o proyecto. Los permisos de varias asignaciones se suman; revocar una no elimina
los demás accesos. Las revocaciones conservan el registro con su fecha de finalización.
La base de datos impide revocar la última asignación activa de administrador.

Crear roles y administrar asignaciones exige `access.manage` con alcance de organización.
Asignar un rol de proyecto no incorpora al usuario al equipo: usa Equipo por proyecto
para vincularlo y poder asignarle tareas.

## Notificaciones

La campana muestra los últimos 100 avisos personales, el total sin leer y los filtros
Todas / Sin leer. Puedes marcar un aviso o todos como leídos y abrir su sección.
Se consulta automáticamente cada 30 segundos mientras la página está visible y al
volver a la ventana. Los avisos aparecen a partir de la instalación del SQL; no se
generan retroactivamente para eventos anteriores.

Los avisos se generan al agregar usuarios a proyectos, asignar responsables de tareas,
cambiar el estado de solicitudes y asignar o revocar roles. Al enviar una solicitud
se avisa a los miembros con permiso de aprobación en ese proyecto, excepto al actor.
Son avisos dentro de Nexo. No se envían correos ni notificaciones push.

## Prueba recomendada

1. Agrega un segundo usuario a un proyecto y asígnale una tarea.
2. Entra con ese usuario y comprueba su campana y el tablero del proyecto.
3. Crea un rol personalizado de consulta y asígnalo a un usuario sin otros roles.
4. Verifica que puede consultar pero no administrar; luego revoca ese rol.
5. Envía una solicitud, apruébala con otro usuario y revisa los avisos de ambos.

`/vista-previa?modulo=administracion` incluye ejemplos sin guardar en Supabase.
Validación local: TypeScript, compilación de producción y pruebas con PostgreSQL
PGlite sobre las migraciones reales, incluidos permisos y protección del último administrador.
