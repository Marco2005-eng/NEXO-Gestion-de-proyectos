# Entrega y supervisión de tareas

Ejecuta `13_entregas_revision_tareas.sql` en el SQL Editor de Supabase después de los scripts 01 a 11. No requiere cambiar el .env ni añadir claves. Crea el bucket privado task-evidence y las políticas de acceso.

1. El jefe crea la tarea y asigna un responsable o colaboradores desde Administración, dentro del proyecto elegido.
2. En Tareas, abre la tarea y entra a Configurar criterios y revisor. Describe el resultado esperado y elige un integrante que no ejecute esa tarea; si no eliges uno, revisan los usuarios con permiso task.manage sobre ese proyecto. Las evidencias son obligatorias por defecto y el jefe puede hacerlas opcionales.
3. El colaborador abre Mis tareas, reporta avance de 0 a 99 %, describe lo realizado y adjunta fotos JPG/PNG/WebP, videos MP4/WebM o PDF. Hasta 10 archivos de 50 MB cada uno.
4. Enviar a revisión cambia la tarea a En revisión y notifica a los revisores. La entrega guarda una copia de los criterios; los archivos y el historial quedan protegidos contra modificación.
5. El jefe o revisor entra a Por revisar, abre las pruebas y solicita correcciones con observaciones o aprueba. Nadie puede revisar una tarea en la que participa como ejecutor, incluso si tiene un cargo superior.
6. Una devolución deja la tarea Por corregir. El colaborador envía otra entrega; se conserva la anterior. Aprobar registra autor, fecha y comentario, completa la tarea y fija el avance en 100 %.

Las tareas completadas antes de instalar este flujo se muestran como Sin revisión registrada. No se inventan aprobaciones históricas. Las nuevas tareas necesitan una entrega aprobada para completarse.

Los archivos se consultan con enlaces que vencen en 10 minutos. Un auditor autorizado puede consultar el historial. Los usuarios ajenos al proyecto no acceden a las entregas.

La vista previa contiene una entrega devuelta como ejemplo; no guarda cambios ni sube archivos. Los archivos subidos y retirados de la lista antes de enviar no se vinculan a entregas y pueden requerir limpieza administrativa posterior del bucket.

## Actualización 14: avances parciales y asignaciones

Ejecuta `14_avances_equipo_revision.sql` después del 13 y actualiza la web. Los archivos ya subidos y las entregas registradas se conservan; las aprobaciones antiguas se consideran finales al 100 %.

En Administración > Asignar tareas > Equipo y revisión, el jefe selecciona responsable, colaboradores y revisor entre integrantes activos del proyecto. También puede hacerlo dentro del detalle de la tarea. Un GF puede revisar al ser asignado como revisor o al tener permiso task.manage en ese proyecto. Escribir GF en el cargo no concede permisos.

La interfaz muestra los nombres de todos los revisores autorizados que no ejecutan esa tarea. Si no hay ninguno, el jefe debe asignarlo antes de enviar. Los jefes con task.manage mantienen supervisión aunque haya un revisor específico.

El colaborador introduce el porcentaje solicitado (por ejemplo, 50 %), explica lo realizado y adjunta al menos una evidencia. La falta de criterios específicos no bloquea: se utiliza la descripción o título de la tarea como referencia, guardada en la entrega. El avance registrado no aumenta hasta la aprobación del supervisor.

El supervisor abre las fotos/videos/PDF del historial, confirma que los revisó y registra el porcentaje que comprobó. Puede validar el solicitado o uno menor, con una explicación, sin reducir el avance ya registrado. Validar 50 % deja la tarea En progreso; aprobar 100 % la completa. Solicitar correcciones conserva el último avance registrado. La decisión, porcentaje y confirmación de revisión se guardan en el historial.

Durante la revisión o después de cerrar la tarea no se puede cambiar su equipo. Las tareas con avances manuales anteriores conservan esos valores; no se inventan evidencias para ellos.

## Supervisión automática por defecto

No necesitas asignar a los jefes en cada tarea: los usuarios activos con permiso task.manage dentro del alcance del proyecto revisan automáticamente. Los ejecutores quedan excluidos. La lista cambia al cambiar sus permisos; no se duplican asignaciones de jefes por tarea.

En Equipo y revisión solo necesitas elegir al responsable. Los colaboradores son opcionales y participan en la ejecución. Elegir un revisor adicional queda como opción para casos específicos y conserva las asignaciones previas. Guardar criterios de aceptación no elimina ese revisor adicional.

Esta simplificación utiliza el SQL 14 ya existente; no requiere otra migración.

## Dónde aprueba el supervisor

En Resumen y Tareas aparece Avances pendientes de revisión. El jefe elige la organización y el proyecto, abre Revisar avance y consulta las fotos o archivos del historial. En la ventana puede ir directamente a Ver fotos y archivos o Revisar avance.

La revisión permite Aprobar avance con el porcentaje comprobado o Solicitar correcciones con observaciones. El jefe confirma que examinó las evidencias antes de registrar la decisión. Validar un avance parcial conserva la tarea en progreso; 100 % aprobado completa la tarea.

Si no aparece una entrega, el colaborador debe pulsar Enviar a revisión; subir una foto sin enviar no crea una revisión. Un ejecutor no puede aprobar esa misma tarea, aunque también sea jefe. La cola incluye al proveedor con permiso de gestión y a los revisores asignados activos.

Estas mejoras de interfaz utilizan los SQL 13 y 14 existentes; no requieren otro script.
# Asignación desde Nueva tarea (SQL 16)

Ejecuta `16_crear_tarea_con_responsable.sql` después de los scripts anteriores y actualiza Nexo.

En Nueva tarea, el jefe elige un proyecto que pueda gestionar, título, estado inicial, prioridad, fecha de entrega y descripción. Busca un integrante activo del proyecto por nombre y selecciona al responsable. La tarea y su asignación se guardan juntos y empiezan con avance 0%. Se notifica al responsable mediante las notificaciones del sistema.

Los colaboradores abren el calendario en Mis tareas por defecto. Los jefes y auditores conservan la vista de todas las tareas. El responsable se puede cambiar desde Editar datos de la tarea o desde Organizar responsables y colaboradores, antes de la revisión y del cierre; al editar se conserva el avance ya validado y los otros colaboradores.

Los jefes y cargos con permiso para gestionar tareas son supervisores automáticos. El jefe puede añadir un revisor adicional al crear o editar. Al entregar, el colaborador también puede indicar un supervisor preferido entre los autorizados; esta preferencia queda registrada, se destaca en su notificación y no restringe el acceso de los demás supervisores. Quien ejecuta la tarea no puede aprobar su propio trabajo.

