# Pruebas piloto con usuarios reales

## Preparación

1. Aplica los SQL pendientes en Supabase, incluidos 20 y 21, siguiendo sus instrucciones. Evita reinstalar el esquema inicial sobre una base existente.
2. El administrador registra las cuentas y asigna los roles y proyectos. Las invitaciones por correo están deshabilitadas por ahora.
3. Crea un proyecto de prueba con presupuesto y materiales identificados como prueba. Los movimientos de stock son inmutables: utiliza un proyecto o entorno de prueba para distinguirlos de operaciones reales.
4. Usa cuentas separadas para administrador, jefe, colaborador y auditor. No pruebes todos los roles con un usuario que también sea administrador, porque los permisos de sus roles se suman.
5. Si existen ingresos anteriores sin precio, valorízalos con su costo histórico y sustento antes de probar nuevas compras.

## Recorrido sugerido

| Prueba | Resultado esperado |
| --- | --- |
| Jefe crea proyecto | Se crea en su organización y queda como responsable |
| Cambiar organización y navegar | Se conserva la selección y no se mezclan proyectos |
| Registrar compra manual y por Excel | Aumentan stock e inversión; se conserva el precio del ingreso |
| Compra que supera presupuesto | Se rechaza toda la operación; no cambian stock ni inversión |
| Jefe solicita ampliación | Queda pendiente y no aumenta el saldo |
| Administrador aprueba ampliación | Aumenta presupuesto una sola vez |
| Colaborador solicita materiales | Solo usa proyecto y materiales de su alcance |
| Aprobar pedido sin stock | No se aprueba; solicita compra o corrección |
| Reservar y entregar | Cambian reserva y stock; no se duplica el gasto de compra |
| Asignar tarea al colaborador | Aparece en sus tareas y calendario |
| Entregar avance con evidencia | Queda en revisión y el supervisor puede consultar evidencias |
| Supervisor valida o pide cambios | Se actualiza el avance validado y queda historial |
| Subir documento restringido | Solo destinatarios autorizados pueden verlo y descargarlo |
| Habilitar corrección de documento | Se conserva historial de versiones |
| Auditor consulta | Puede consultar lo autorizado sin modificar datos |
| Reportes y CSV | Coinciden con operaciones y filtros; exportan todas las filas filtradas |
| Roles sin permisos de administración | No pueden gestionar accesos ni ampliar presupuesto directamente |
| Pantalla móvil y tema oscuro | Formularios y navegación siguen siendo utilizables |

Registra cada incidencia con cuenta/rol, proyecto, pasos, resultado esperado, resultado observado y captura sin credenciales. Primero corrige errores que bloqueen el flujo o muestren datos fuera del alcance; después ajusta interfaz y comodidad.

La revisión automática de entregas es orientativa: no certifica visualmente que una fotografía demuestre el trabajo. La aprobación manual sigue siendo necesaria.
