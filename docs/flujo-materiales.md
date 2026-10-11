# Flujo operativo de materiales

## 1. Registro e ingreso

El responsable de almacén crea el material con categoría, unidad de medida,
ubicación y stock mínimo. Cada cantidad inicial o compra genera un movimiento de
entrada; nunca se cambia el saldo sin dejar un movimiento asociado.

## 2. Solicitud

Un miembro selecciona un proyecto autorizado, material, cantidad, fecha requerida
y justificación. La solicitud conserva al solicitante, la tarea relacionada y los
archivos de sustento.

## 3. Validación y aprobación

El sistema comprueba disponibilidad. El aprobador revisa necesidad, cantidad,
costo y presupuesto. Puede aprobar, rechazar o devolver para corrección. El
solicitante no puede aprobar su propio pedido.

## 4. Reserva

Al aprobar, la cantidad pasa de disponible a reservada para impedir que otra
solicitud utilice el mismo stock. La existencia física total todavía no cambia.

## 5. Entrega

Almacén registra quién entrega, quién recibe, fecha, cantidad real y evidencia.
La cantidad entregada sale del stock físico y de la reserva.

## 6. Uso o devolución

Los consumibles requieren un reporte de uso. Los equipos prestables requieren
devolución y estado de conservación. Una devolución genera un movimiento de
entrada y cualquier daño queda como incidencia.

## 7. Cierre

La solicitud se cierra cuando se confirma el consumo o la devolución. El historial
completo permanece disponible para auditoría y reportes.

## Estados recomendados

```text
Borrador → Pendiente → Aprobada → Reservada → Entregada → Cerrada
               ├── Rechazada
               └── Requiere corrección
```

## Registros principales

```text
materials
material_categories
warehouses
material_stock
material_requests
material_request_items
material_approvals
material_deliveries
material_usage_reports
material_returns
material_stock_movements
```

El saldo visible debe calcularse desde movimientos o actualizarse mediante una
operación transaccional. Así se evita que el inventario y el historial presenten
valores diferentes.
