# Arquitectura de Nexo

Decisión: monolito modular con Next.js, TypeScript y Supabase.

- `src/app`: rutas y composición de páginas.
- `src/components`: presentación compartida.
- `src/features/<modulo>/domain`: reglas puras y estados.
- `src/features/<modulo>/application`: casos de uso y coordinación.
- `src/features/<modulo>/infrastructure`: consultas y adaptadores externos.
- `src/lib`: conexiones compartidas.
- `supabase/migrations`: integridad, transacciones y autorización RLS.

Las consultas requieren sesión y usan la clave pública con cookies del usuario.
RLS limita los registros visibles. Las futuras escrituras deben validar también
permisos funcionales y alcance en sus casos de uso.

MCP es un adaptador opcional para conectar asistentes de IA. Sus herramientas
deben invocar los mismos casos de uso, con identidad y auditoría. No reemplaza
la arquitectura del sistema. Si se quería decir MVC, esta estructura conserva
la separación de presentación, coordinación y datos, organizada por módulo.

## Flujos

Interfaz → caso de uso → validación y autorización → operación SQL → resultado.
Las transiciones de materiales replican la migración existente. Las reglas puras
no reemplazan las comprobaciones SQL. Reserva, entrega, devolución y cancelación
con reservas deben ejecutarse mediante funciones SQL transaccionales, con bloqueo
de filas e idempotencia. No usar varias llamadas independientes para estas acciones.
Los correos futuros deben usar una outbox con reintentos, registrada en la misma
transacción que la operación de negocio.

## Entrega actual y trabajo pendiente

Actualización de interfaces: resumen con indicadores, filtros, tarjetas de
proyectos, tablero de tareas, modales y formularios conectados para proyectos,
tareas, catálogo de materiales y diagramas. `05_flujos_interfaces.sql` habilita
solicitudes y operaciones atómicas de aprobación, reserva y entrega completa.
`06_usuarios_asignaciones.sql` habilita la consulta de cuentas de la organización,
registro mediante Auth Admin y asignaciones de equipo y responsable por proyecto.
Ver `usuarios-y-asignaciones.md` para configurar la clave privada del servidor.
La vista pública `/vista-previa` usa datos ilustrativos y no guarda cambios.
Las notas de entrega inicial que siguen describen el estado anterior a esta
actualización, no el alcance vigente de las interfaces.

Implementado: aplicación ejecutable, rutas de nueve módulos, consultas iniciales,
inicio y cierre de sesión, renovación de cookies, reglas de estados e inventario
y pruebas unitarias. Administración consulta áreas. Las listas muestran hasta
100 registros; aún no hay paginación ni formularios operativos.

Pendiente: CRUD, invitaciones, recuperación de contraseña, funciones SQL de flujos,
aprobaciones operativas, archivos, correos, exportaciones y pruebas de RLS.
La migración existente se conserva y no se ha aplicado ni auditado exhaustivamente.
Antes de habilitar escrituras hay que revisar políticas y triggers. Las pruebas
unitarias no validan concurrencia ni permisos de la base de datos.

## Ejecución

`npm install`, copiar `.env.example` a `.env.local`, completar las variables y
ejecutar `npm run dev`. Sin Supabase puede revisarse la estructura sin datos.
Con Supabase se requiere una cuenta y la asignación inicial de organización y
roles mediante el bootstrap del esquema existente.

Validación: `npm run typecheck`, `npm test`, `npm run build`.
