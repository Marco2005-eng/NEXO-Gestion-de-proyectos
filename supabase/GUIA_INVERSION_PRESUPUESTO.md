# Inversión de materiales y presupuesto

Ejecuta `21_inversion_materiales_presupuesto.sql` después de los SQL anteriores, especialmente el 15. La migración equivalente está en `migrations/20261011110000_material_investment_budget.sql`.

## Registrar y actualizar materiales

En Materiales selecciona el proyecto. Registrar compra / material permite elegir un material existente o crear uno nuevo, indicar cantidad, precio de esta compra y almacén. La compra suma stock y registra inversión de forma transaccional. Importar Excel también registra inversión; las existencias iniciales cuentan como inversión inicial asignada al proyecto. Solo catálogo crea una ficha sin existencias ni gasto. Actualizar material permite cambiar nombre y stock mínimo; las nuevas cantidades y precios se registran como ingresos, conservando el historial.

## Balance

Materiales y Reportes → Inversión y compras muestran presupuesto autorizado, inversión acumulada, saldo disponible y ampliaciones. El balance es acumulado, independiente del filtro de fechas del listado de reportes. No se suma dos veces el costo al entregar materiales: compra = inversión; entrega = salida del stock. No incluye pagos, servicios, mano de obra ni otros gastos que aún no se registran en Nexo.

Los movimientos anteriores al SQL 21 no conservaron su precio de compra: no se reconstruye usando el precio actual. En Ver ingresos y costos, el administrador indica el costo unitario histórico y su sustento para cada ingreso pendiente. Mientras haya ingresos por valorizar no se certifica el saldo ni se permiten nuevas compras. El registro deja usuario, fecha y sustento de la valorización. Las compras nuevas conservan su precio incluso si otra compra cambia el precio actual.

## Ampliaciones y control

El jefe solicita un importe adicional y justificación. El administrador con Administrar presupuesto, o el superadministrador, aprueba o rechaza desde el historial de ampliaciones. La aprobación aumenta el presupuesto una sola vez. El jefe no puede modificar directamente el presupuesto de un proyecto existente. Los administradores pueden configurar el presupuesto total y valorizar el historial. El permiso está disponible en Roles y permisos y se otorga por defecto al rol Administrador.

Se comprueba el presupuesto en la base de datos al registrar una compra; si es insuficiente, se revierte todo el ingreso, incluyendo el stock. Una importación con varias filas es atómica. Al aprobar solicitudes de materiales se verifica que exista stock disponible. Aprobar no vuelve a descontar presupuesto; reservar compromete stock y entregar lo descuenta. La reserva sigue siendo necesaria porque otras solicitudes pueden utilizar stock entre aprobación y reserva.

Las ampliaciones pendientes generan una notificación a administradores autorizados; las decisiones notifican a quien las solicitó.
