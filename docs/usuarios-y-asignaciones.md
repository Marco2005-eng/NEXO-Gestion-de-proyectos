# Usuarios y tareas por proyecto

## Activar

Ejecuta `supabase/06_usuarios_asignaciones.sql` en SQL Editor como postgres,
después del esquema inicial. El archivo corresponde a la migración
`20261010010000_team_assignments.sql`: aplica uno de los dos, no ambos como
versiones independientes. No reemplaza tablas ni modifica los roles existentes.

Para registrar nuevas cuentas desde Nexo, agrega esta variable en `.env.local`:

```dotenv
SUPABASE_SECRET_KEY=tu_clave_privada_de_supabase
```

Obtén la Secret key desde Settings > API Keys. No le agregues NEXT_PUBLIC ni la
copies en el chat. Reinicia `npm run dev` después de configurarla. La variable
es opcional para consultar miembros y asignar personas ya registradas.

## Probar el flujo

1. En Administración > Usuarios registrados, crea una cuenta con nombre,
   correo, cargo y contraseña inicial (mínimo diez caracteres). El administrador
   confirma la cuenta al registrarla; no se envía correo desde este formulario.
2. En Equipo por proyecto, selecciona un proyecto y agrega al usuario.
   Elige su función y rol. El rol tiene alcance únicamente en ese proyecto.
3. En Asignar tareas, selecciona el mismo proyecto. En cada tarea aparecen
   únicamente miembros activos del equipo; elige uno y guarda la asignación.
4. Ingresa con la cuenta nueva para verificar sus proyectos y tareas autorizados.

El registro no inicia sesión con la cuenta creada ni cambia la sesión del
administrador. Las contraseñas pertenecen a Supabase Auth y no se guardan en las
tablas ni en los datos que recibe el navegador. Los correos consultados
pertenecen a miembros de la organización, no a todos los usuarios de la plataforma.

Asignar una tarea reemplaza a su responsable principal, conservando colaboradores
y revisores. Agregar un miembro concede un rol adicional por proyecto; no revoca
roles previamente otorgados. Las bajas de equipo, cambios/revocación de roles y
recuperación de contraseña requieren un flujo posterior.

Las pruebas usan PostgreSQL local con Auth y Storage emulados: verifican permisos,
rechazo de asignaciones fuera del equipo y cambio transaccional de responsable.
El registro de cuentas mediante Auth Admin requiere prueba en tu Supabase después
de configurar la clave privada; no se crearon cuentas reales durante el desarrollo.
