# Proveedor, organizaciones y proyectos

## Activación

1. Ejecuta `supabase/11_organizaciones_superadministrador.sql` después de los SQL anteriores.
2. Revisa el correo en `supabase/12_activar_superadministrador.sql`. Está preparado para `2023100659@ucss.pe`. Ejecuta el archivo solo si esa cuenta será el proveedor del servicio.
3. Recarga Nexo. La cuenta elegida verá **Administrar Nexo** en el menú.

La asignación global se hace desde SQL Editor. Los usuarios autenticados no pueden insertar su propia cuenta en la tabla de superadministradores.

## Responsabilidades

| Nivel | Funciones |
| --- | --- |
| Superadministrador de Nexo | Crea organizaciones, designa su administrador inicial y gestiona organizaciones y proyectos del sistema. |
| Administrador de organización | Configura el nombre de su organización, registra usuarios, crea proyectos y designa sus jefes. |
| Jefe de proyecto | Gestiona el proyecto asignado, registra colaboradores como Miembro, distribuye tareas y organiza el equipo. |
| Colaborador | Trabaja según los permisos de su rol en los proyectos asignados. |

**Administrar Nexo** permite crear una organización con una cuenta existente como administrador inicial. La cuenta debe existir en Authentication. El nuevo administrador no recibe acceso global.

**Administración → Organización** permite cambiar el nombre y asignar un jefe por proyecto. Cambiar el jefe revoca la asignación previa de Jefe de proyecto en ese proyecto; conserva sus otros roles y su pertenencia al equipo.

En **Proyectos** aparece el jefe designado. Solo los permisos `project.create` permiten crear proyectos; el rol estándar Jefe de proyecto no incluye ese permiso.

Los jefes registran colaboradores desde Administración. Deben seleccionar uno de los proyectos que gestionan. El registro crea la cuenta, la membresía, el equipo y el rol Miembro limitado al proyecto. La parte de membresía/equipo/rol se guarda en una transacción; si falla, se intenta eliminar la cuenta Auth recién creada. No permite otorgar roles superiores sin `access.manage`.

Los roles son acumulativos: si la persona también tiene un rol de organización, ese acceso permanece. La designación de un jefe no degrada permisos otorgados por otros roles.

No se implementaron cobros, suscripciones ni un registro público de organizaciones.

## Verificación

Pruebas con PostgreSQL PGlite sobre las migraciones reales: crear organización requiere superadministrador, la autoasignación global se bloquea, el jefe no puede cambiar el nombre de la organización, otra organización permanece invisible para él y un colaborador creado recibe únicamente su proyecto.
