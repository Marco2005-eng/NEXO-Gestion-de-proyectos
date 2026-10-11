# Modelo de roles y permisos

El acceso efectivo de un usuario se obtiene combinando tres elementos:

```text
Rol + permisos funcionales + proyectos asignados = acceso efectivo
```

## 1. Rol

Representa una configuración reutilizable, por ejemplo: administrador, jefe de
proyecto, jefe de área, aprobador, miembro, gestor de materiales o auditor.

## 2. Permisos funcionales

Definen acciones concretas y no solamente nombres de pantallas:

- `project.view`, `project.create`, `project.update`
- `task.view`, `task.create`, `task.assign`, `task.update_own`
- `material.view`, `material.request`, `material.deliver`
- `approval.view`, `approval.decide`
- `report.view`, `report.export`
- `user.invite`, `role.manage`, `audit.view`

## 3. Alcance

Limita los registros donde el permiso se puede utilizar:

- Toda la organización.
- Una o varias áreas.
- Uno o varios proyectos.
- Registros creados por el propio usuario.
- Tareas asignadas al propio usuario.

Una persona puede tener dos o tres proyectos sin obtener acceso a los demás. Si
también tiene varias funciones, se unen sus permisos pero se mantiene el alcance
de cada asignación.

## Regla de seguridad

Ocultar botones y opciones del menú mejora la experiencia, pero no constituye
seguridad. La aplicación final debe validar cada operación en el servidor y
aplicar políticas RLS en Supabase. Una solicitud directa a la base de datos debe
ser rechazada aunque el usuario intente evitar la interfaz.

## Tablas previstas

```text
roles
permissions
role_permissions
user_role_assignments
user_project_assignments
user_area_assignments
```

`user_role_assignments` debe admitir un alcance asociado para permitir, por
ejemplo, que una persona sea jefa en un proyecto y solamente colaboradora en
otro.
