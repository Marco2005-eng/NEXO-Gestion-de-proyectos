# Nexo · Gestión de proyectos y recursos

**Organiza proyectos, asigna responsables y controla tareas, materiales y presupuesto desde un mismo espacio de trabajo.**

Nexo está dirigido a organizaciones que necesitan saber quién realiza cada actividad, cómo avanza, cuándo debe terminar y qué recursos consume. Cada organización mantiene sus proyectos y accesos; el proveedor administra el sistema y las organizaciones que utilizan el servicio.

> **Estado:** versión funcional en etapa de pruebas piloto. Las invitaciones por correo tienen interfaz preparada, pero el envío permanece deshabilitado hasta configurar el dominio y el servicio de correo.

## Contenido

- [Cómo funciona Nexo](#cómo-funciona-nexo)
- [Módulos](#módulos)
- [Roles y permisos](#roles-y-permisos)
- [Flujos principales](#flujos-principales)
- [Tecnologías y arquitectura](#tecnologías-y-arquitectura)
- [Instalación y configuración](#instalación-y-configuración)
- [Ejecutar el proyecto](#ejecutar-el-proyecto)
- [Pruebas y validación](#pruebas-y-validación)
- [Documentación](#documentación)
- [Alcance actual y siguientes pasos](#alcance-actual-y-siguientes-pasos)

## Cómo funciona Nexo

1. El **superadministrador** crea las organizaciones y designa a quienes las administran.
2. El **administrador de la organización** configura sus usuarios, áreas, roles y permisos.
3. El **jefe de proyecto** gestiona sus proyectos, incorpora colaboradores y asigna tareas. Por defecto puede crear nuevos proyectos dentro de su organización.
4. El **colaborador** consulta sus tareas, reporta avances, adjunta evidencias y solicita materiales.
5. El **jefe o revisor autorizado** revisa las entregas y valida avances o solicita correcciones.
6. Los responsables de materiales aprueban solicitudes, reservan existencias y registran entregas.
7. Los reportes permiten consultar avances, movimientos de materiales e inversión del proyecto.

La organización y el proyecto seleccionados se conservan al navegar entre módulos. Los registros y las acciones disponibles dependen de los permisos de cada usuario.

## Módulos

| Módulo | Función principal |
| --- | --- |
| Resumen | Consultar indicadores, proyectos destacados, próximas tareas y pendientes |
| Proyectos | Definir alcance, área, fechas, presupuesto y responsables |
| Tareas | Asignar trabajo, consultar el calendario y supervisar avances con evidencias |
| Materiales | Registrar catálogo, compras e inventario por almacén, manualmente o desde Excel |
| Solicitudes | Pedir materiales para un proyecto y, opcionalmente, una tarea |
| Aprobaciones | Revisar solicitudes de materiales y continuar su flujo operativo |
| Documentos | Compartir archivos con destinatarios autorizados y conservar versiones corregidas |
| Diagramas | Consultar y editar diagramas de flujo Mermaid en una vista interactiva |
| Reportes | Consultar inversión, movimientos, entregas, inventario, avances y solicitudes; exportar CSV |
| Administración | Gestionar usuarios, equipos, asignaciones, roles, permisos y organización |
| Mi perfil y apariencia | Actualizar datos personales y ajustar tema y tamaño de letra |

Las ampliaciones de presupuesto se solicitan y revisan en el **balance del proyecto**, disponible en Materiales y en Reportes → Inversión y compras. Las notificaciones informan asignaciones y cambios relevantes de los flujos.

## Roles y permisos

| Rol o función | Alcance habitual |
| --- | --- |
| Superadministrador de Nexo | Administra todas las organizaciones del sistema |
| Administrador de organización | Gestiona su organización, usuarios, permisos y presupuesto |
| Jefe de proyecto | Gestiona los proyectos asignados y puede crear nuevos dentro de su organización |
| Jefe de área | Gestiona actividades dentro del área o alcance que tenga asignado |
| Colaborador | Ejecuta las tareas asignadas y reporta resultados |
| Revisor autorizado | Supervisa entregas según sus permisos o asignación de revisión |
| Responsable de materiales / aprobador | Gestiona inventario o decisiones de solicitudes según sus permisos |
| Auditor | Consulta la información autorizada sin modificar las operaciones |

**Los nombres de los roles no sustituyen a los permisos.** Las acciones efectivas dependen de los permisos configurados y del alcance: organización, área o proyecto. Los permisos de varios roles asignados se suman.

El superadministrador y los administradores autorizados pueden modificar permisos desde **Administración → Roles y permisos**. Cambiar un rol afecta a todos los usuarios que lo tengan dentro de su alcance. Se conserva la protección del último administrador y la gestión de accesos del rol Administrador al guardar sus permisos.

El permiso de crear proyectos puede retirarse al jefe. Tener ese permiso no concede acceso general a todos los proyectos existentes; al crear uno nuevo, el jefe queda como responsable de ese proyecto.

## Flujos principales

### Tareas y supervisión

```text
Asignar tarea → Ejecutar y reportar avance → Adjuntar evidencias
             → Enviar a revisión → Validar avance o pedir correcciones
```

- Al crear una tarea se seleccionan proyecto, responsable, prioridad, descripción y fecha límite; el avance inicial es cero.
- El colaborador consulta sus asignaciones en el calendario y presenta resultados con evidencias, como fotografías, videos cortos o PDF.
- Los jefes y usuarios con permisos de revisión pueden supervisar las entregas; también puede indicarse un revisor preferido autorizado.
- El supervisor revisa los criterios y evidencias, valida el porcentaje alcanzado o solicita cambios. Se conserva el historial de entregas y decisiones.
- La comprobación automática es **orientativa**: analiza descripción y metadatos de archivos. No certifica visualmente el contenido de una fotografía; la decisión manual sigue siendo necesaria.

### Materiales y solicitudes

```text
Registrar compra → Aumentar stock → Solicitar materiales → Enviar a aprobación
                 → Aprobar → Reservar → Entregar → Confirmar recepción
```

- **Registrar compra / material:** permite crear un producto o ingresar más unidades de uno existente, con cantidad, precio y referencia opcional de compra.
- **Importar Excel:** permite ingresar varios materiales y relacionar las columnas del archivo con los campos del sistema.
- **Solo catálogo:** crea la ficha del material sin existencias ni inversión.
- **Actualizar material:** cambia nombre y stock mínimo. Las nuevas cantidades y precios se registran como ingresos para conservar el historial.
- Al aprobar solicitudes se comprueba el stock disponible. La reserva compromete existencias y la entrega descuenta stock físico.
- Aprobar no reserva automáticamente: la reserva sigue siendo una operación necesaria, y vuelve a comprobar la disponibilidad.

### Presupuesto e inversión

```text
Presupuesto autorizado − Inversión registrada = Saldo disponible

Solicitar ampliación → Revisión del administrador → Aprobar o rechazar
```

**La compra consume presupuesto y aumenta stock. La entrega al colaborador reduce stock, sin volver a contar la compra como gasto.** Las existencias iniciales se registran como inversión inicial del proyecto.

Cada ingreso nuevo conserva su precio histórico. Si una compra supera el saldo disponible, se rechaza toda la operación y no se modifica el inventario. Una importación con varias filas también se revierte completa si no puede realizarse.

El jefe solicita ampliaciones con importe y justificación. El administrador autorizado o el superadministrador las revisa; una aprobación aumenta el presupuesto una sola vez. La solicitud pendiente no aumenta el saldo.

Los ingresos anteriores a esta funcionalidad pueden no tener precio histórico. Aparecen como **pendientes de valorizar**: el administrador registra el costo real y su sustento desde **Ver ingresos y costos**. Mientras haya costos pendientes, el saldo no se confirma y se bloquean nuevas compras.

El balance muestra la inversión acumulada completa del proyecto; los filtros de fechas del reporte aplican al listado del período. Los importes actuales corresponden a materiales registrados, **no a un sistema contable de pagos**, servicios o mano de obra.

### Documentos y versiones

```text
Cargar documento → Elegir destinatarios → Consultar o descargar
                → Habilitar corrección → Cargar nueva versión → Conservar historial
```

Los documentos no se muestran automáticamente a todos. Se pueden seleccionar colaboradores del proyecto, todo el equipo actual u otros grupos de acceso disponibles, como un área o los responsables de aprobar materiales.

La opción de seleccionar todo el equipo incluye a los miembros actuales; no agrega automáticamente a quienes se incorporen después. Las versiones corregidas conservan el historial y requieren que la carga esté habilitada para los destinatarios.

## Tecnologías y arquitectura

| Componente | Tecnología |
| --- | --- |
| Aplicación web | Next.js 16, React 19 y TypeScript |
| Datos y autenticación | Supabase: PostgreSQL y Auth |
| Archivos | Supabase Storage con controles de acceso |
| Importación de materiales | ExcelJS |
| Diagramas | Mermaid |
| Entorno compartido | Docker y Docker Compose |
| Pruebas | Node Test Runner, TSX y PostgreSQL mediante PGlite |

La aplicación utiliza un **monolito modular**: cada área funcional reúne su interfaz, lógica de aplicación y acceso a datos. Las operaciones sensibles se verifican en el servidor y mediante funciones transaccionales y políticas RLS en Supabase.

```text
src/
├── app/                 Rutas y estilos de la aplicación
├── components/          Componentes compartidos
├── features/            Módulos funcionales
└── lib/                 Configuración e integración con Supabase
supabase/
├── migrations/          Migraciones de base de datos
└── *.sql                Scripts para ejecutar desde SQL Editor
public/                  Recursos y plantillas descargables
tests/                   Pruebas de lógica y flujos de PostgreSQL
docs/                    Guías de configuración y funcionamiento
Dockerfile               Imagen de desarrollo y aplicación compilada
compose.yaml             Servicios Docker
```

`dist/` conserva el prototipo HTML original. La aplicación actual está en `src/`.

## Instalación y configuración

### 1. Preparar Supabase

Para una instalación nueva sigue [Conectar Supabase](docs/conectar-supabase.md): instala el esquema inicial, crea la cuenta de administrador en Authentication y vincúlala con la organización.

Después aplica las mejoras funcionales en su orden numérico, desde los SQL **05 a 21**. El **12** requiere indicar el correo de la cuenta que será superadministrador; no lo ejecutes sin revisar ese dato. El **04** carga ejemplos y es opcional. El **03** contiene consultas de verificación.

En una base existente, ejecuta únicamente los scripts pendientes. **No reinstales el esquema inicial sobre la base actual.** Los scripts numerados y sus migraciones equivalentes representan las mismas mejoras: elige un procedimiento y evita duplicar la instalación inicial o mezclar historiales sin reconciliarlos.

Docker ejecuta la web; **no instala ni migra automáticamente Supabase**.

### 2. Configurar variables de entorno

Copia `.env.example` a `.env.local` en la raíz del proyecto:

```powershell
Copy-Item .env.example .env.local
```

Completa los valores:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://TU_PROYECTO.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA
SUPABASE_SECRET_KEY=
```

| Variable | Uso |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | URL del proyecto Supabase |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Clave pública para conectar la web |
| `SUPABASE_SECRET_KEY` | Clave privada del servidor, necesaria para registrar cuentas desde Administración |

Las variables `NEXT_PUBLIC_*` son públicas y se incorporan a la compilación. **Nunca coloques la clave secreta en una variable con ese prefijo.** `.env.local` está excluido de Git y del contexto de construcción Docker.

Si no configuras la clave secreta, puedes trabajar con cuentas existentes, pero el registro de nuevas cuentas desde Nexo estará deshabilitado. La contraseña de PostgreSQL no se utiliza como contraseña de ingreso a Nexo.

## Ejecutar el proyecto

### Opción A: Docker

Requiere Docker Desktop con contenedores Linux. No necesitas instalar Node.js ni Next.js en la PC; la primera construcción descarga las dependencias dentro del contenedor.

**Para probar la aplicación compilada:**

```powershell
docker compose --env-file .env.local up --build -d app
```

**Para desarrollar con recarga del código:**

```powershell
docker compose --env-file .env.local --profile desarrollo up --build desarrollo
```

No ejecutes ambos servicios simultáneamente en el mismo puerto. Para cambiar de modo, detén primero el servicio anterior. Si cambian el código o las variables públicas, reconstruye la imagen de la aplicación compilada.

Para detener los servicios:

```powershell
docker compose --env-file .env.local down
```

Consulta la [guía de Docker](docs/docker.md) para compartir una imagen ya construida, sincronizar dependencias y probar desde otros equipos.

### Opción B: Node.js

Usa Node.js 24 y, desde la raíz del proyecto, ejecuta:

```powershell
npm ci
npm run dev
```

En ambas opciones abre [http://localhost:3000](http://localhost:3000) e inicia sesión con una cuenta creada y vinculada a Nexo. La ruta `/vista-previa` permite recorrer las interfaces sin guardar datos.

## Pruebas y validación

```powershell
npm run typecheck
npm test
npm run build
```

Las pruebas cubren permisos y alcance, tareas y revisión, materiales, inversión, ampliaciones, documentos, importación y persistencia de selección. Las pruebas de PostgreSQL usan PGlite y no modifican el proyecto remoto de Supabase.

**Última validación local:** 27 pruebas aprobadas y compilación standalone correcta. El contenedor Docker todavía debe validarse con su primera construcción en un equipo con Docker instalado.

Para probar con usuarios reales, utiliza cuentas separadas de administrador, jefe, colaborador y auditor. Si una cuenta conserva un rol de administrador adicional, sus permisos se suman y no representa una prueba válida de un rol restringido.

Sigue el recorrido de [pruebas piloto](docs/pruebas-piloto.md) y registra las incidencias con rol, proyecto, pasos y resultado esperado.

## Documentación

| Guía | Contenido |
| --- | --- |
| [Supabase](docs/conectar-supabase.md) | Instalación inicial y conexión |
| [Usuarios y asignaciones](docs/usuarios-y-asignaciones.md) | Cuentas, equipos y distribución de tareas |
| [Permisos de proyectos](supabase/GUIA_PERMISOS_PROYECTOS.md) | Creación de proyectos y edición de permisos |
| [Entregas de tareas](supabase/GUIA_ENTREGAS_TAREAS.md) | Evidencias, avances y supervisión |
| [Materiales](supabase/GUIA_MATERIALES.md) | Excel, inventario y solicitudes |
| [Inversión y presupuesto](supabase/GUIA_INVERSION_PRESUPUESTO.md) | Compras, balance y ampliaciones |
| [Documentos](GUIA_DOCUMENTOS.md) | Destinatarios, archivos y versiones |
| [Docker](docs/docker.md) | Ejecución y colaboración en otros equipos |
| [Pruebas piloto](docs/pruebas-piloto.md) | Casos de prueba con cuentas reales |

Este README describe el funcionamiento actual. Algunas guías históricas conservan propuestas de etapas anteriores; para las mejoras recientes, consulta las guías funcionales y los SQL correspondientes.

## Alcance actual y siguientes pasos

| Estado | Funcionalidad |
| --- | --- |
| Disponible para pruebas | Proyectos, tareas, revisión manual, materiales, solicitudes, presupuesto, documentos, diagramas y reportes |
| Orientativa | Comprobación automática de entregas; no sustituye la revisión de evidencias por una persona |
| Preparada, deshabilitada | Interfaz de invitaciones por correo |
| Pendiente de verificar | Construcción y ejecución del contenedor Docker |
| Siguiente etapa | Pruebas con usuarios reales, corrección de incidencias y publicación de la aplicación |
| Posterior | Dominio, configuración del servicio de correo y activación de invitaciones |

Los colaboradores del desarrollo pueden usar Docker para trabajar con el mismo entorno. Los usuarios finales accederán desde el navegador a la URL donde se publique Nexo; no necesitarán instalar Docker.
