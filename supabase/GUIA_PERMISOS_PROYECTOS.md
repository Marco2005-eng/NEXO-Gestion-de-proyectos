# Permisos de proyectos y administración

Ejecuta `20_permisos_jefes_proyectos.sql` en el SQL Editor de Supabase, después de los SQL anteriores. La migración equivalente está en `migrations/20261011100000_project_creation_role_permissions.sql`; utiliza una de las dos vías.

En Administración → Roles y permisos → Jefe de proyecto → Editar permisos, el superadministrador o el administrador de la organización puede activar o retirar Crear proyectos. Los roles del sistema conservan su nombre y código, pero permiten cambiar sus permisos dentro de la organización seleccionada. La edición afecta a todos los usuarios con ese rol, dentro del alcance asignado.

Por defecto, los jefes actuales y los nuevos reciben Crear proyectos. Una asignación de jefe en un proyecto permite crear otros proyectos dentro de la misma organización, sin otorgar acceso a todos los proyectos existentes. El creador con rol de jefe queda como responsable del nuevo proyecto y recibe el rol con alcance de ese proyecto.

La gestión de accesos del rol Administrador se conserva al guardar sus permisos. Se mantiene la protección existente contra revocar al último administrador. La configuración de roles de una organización no modifica los roles de otra.

Para probar: inicia sesión como jefe, crea un proyecto y verifica que puedas asignar tareas y miembros allí. Como administrador, retira Crear proyectos y comprueba que ya no aparezca Nuevo proyecto para ese jefe (si no tiene otro rol que otorgue el permiso). Recarga la sesión abierta del jefe para actualizar la interfaz; la base de datos comprueba los permisos en cada operación.
