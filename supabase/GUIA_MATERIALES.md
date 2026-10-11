# Materiales y solicitudes

En SQL Editor de Supabase ejecuta `15_materiales_excel_solicitudes.sql` después de los scripts anteriores (hasta el 14). Conserva los datos. Después actualiza Nexo para volver a cargar los permisos.

## Inventario del proyecto

El jefe de proyecto obtiene permisos para importar, aprobar y gestionar stock únicamente dentro del alcance de su rol. Los administradores conservan su alcance de organización. Un colaborador consulta el inventario y solicita materiales; no puede importar ni aprobar.

En **Materiales → Importar Excel**, selecciona el proyecto y el almacén. Puedes crear automáticamente un almacén propio del proyecto. Un jefe con permisos de un solo proyecto puede importar en su almacén; para importar en un almacén compartido se requiere permiso de stock de toda la organización.

La plantilla descargable tiene ejemplos que debes reemplazar antes de importarla. Se admiten `.xlsx` de hasta 10 MB, con hasta 1 000 filas por carga y 100 columnas. Puedes elegir la hoja, la fila de encabezados y relacionar columnas de tu archivo.

| Columna | Requisito |
| --- | --- |
| Código / SKU | Obligatorio, único dentro del archivo. Se normaliza en mayúsculas. |
| Material | Nombre obligatorio. |
| Unidad | Obligatoria; debe coincidir con el catálogo si el código ya existe. |
| Cantidad | Número de unidades o metros, mayor o igual que cero. |
| Precio | Precio unitario en soles, mayor o igual que cero. |
| Stock mínimo | Opcional; si falta se usa cero para materiales nuevos. |
| Tipo | Opcional: consumible o retornable; por defecto consumible. |

No incluyas filas de totales ni fórmulas: pega como valores. Si las celdas contienen texto numérico, usa coma o punto decimal y ningún separador de miles. Cantidades, mínimos y precios admiten hasta cuatro decimales.

**Existencias iniciales** registra saldo para materiales sin movimientos previos en ese almacén. **Nueva compra / ingreso** suma las cantidades del archivo al stock físico. Nunca carga un saldo actualizado reemplazando las existencias: eso duplicaría el inventario. El mismo archivo se bloquea si ya fue importado en el mismo almacén, aunque le cambies el nombre.

La importación es una transacción: cualquier error revierte toda la carga. Los códigos existentes conservan nombre, unidad, tipo y mínimo del catálogo; una unidad o tipo diferente bloquea la importación. El precio del almacén se actualiza al valor del último ingreso (no calcula costo promedio contable). Las solicitudes guardan una copia del precio al preparar o corregir el pedido, para conservar su monto aunque luego cambie el catálogo.

## Pedido y entrega

1. **Colaborador:** abre Solicitudes o usa Solicitar materiales en Materiales; elige proyecto, tarea asignada (o pedido general), almacén, cantidades, fecha y justificación. Se guarda un borrador.
2. **Colaborador:** abre el pedido y pulsa Enviar a aprobación.
3. **Jefe o aprobador:** abre Aprobaciones, revisa cantidades, necesidad y costo. Aprueba, pide correcciones con un motivo o rechaza. No puede decidir su propio pedido.
4. **Colaborador:** si se pidió corrección, usa Editar pedido y vuelve a enviarlo.
5. **Responsable de stock:** en el pedido aprobado pulsa Reservar materiales. Se verifica la disponibilidad de todos los materiales en una sola transacción.
6. **Responsable de stock:** prepara el pedido y registra la entrega completa al colaborador. Se descuenta el stock físico y se libera su reserva.
7. **Colaborador:** en el pedido entregado pulsa Confirmar que recibí los materiales, después de comprobar las cantidades.

Ejemplo: 100 metros físicos, 0 reservados → reservar 15 deja 100 físicos, 15 reservados y 85 disponibles → entregar deja 85 físicos, 0 reservados y 85 disponibles. La aprobación no descuenta stock y repetir la entrega no lo vuelve a descontar.

Un pedido utiliza un solo almacén; para dos almacenes crea dos pedidos. Esta versión entrega la cantidad completa aprobada, con confirmación separada del receptor. Las entregas parciales, devoluciones de equipos y reportes de consumo requieren una siguiente ampliación; importar un equipo retornable aún no controla su devolución desde la interfaz.

Las notificaciones existentes avisan a los aprobadores del proyecto cuando llega un pedido y al solicitante cuando cambia el estado. El historial conserva decisiones y comentarios. Las cargas quedan registradas en `material_import_batches` y los ingresos, reservas y entregas en `stock_movements`.
