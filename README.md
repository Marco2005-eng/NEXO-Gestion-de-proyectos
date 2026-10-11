# Nexo — Gestión de proyectos y materiales

Aplicación Next.js + TypeScript + Supabase con arquitectura de monolito modular.

Incluye organizaciones y roles, proyectos, tareas con calendario y revisión de evidencias, inventario y compras manuales o por Excel, solicitudes de materiales, presupuesto y ampliaciones, documentos con destinatarios y versiones, diagramas interactivos y reportes exportables. Las invitaciones por correo están preparadas en la interfaz y permanecen deshabilitadas.

## Ejecutar con Docker

Requiere Docker Desktop con contenedores Linux. Copia `.env.example` a `.env.local` y configura Supabase:

```powershell
docker compose --env-file .env.local up --build -d app
```

Abre http://localhost:3000. No requiere instalar Node.js ni Next.js en el equipo. La primera construcción instala dependencias dentro del contenedor.

Para desarrollar con recarga del código:

```powershell
docker compose --env-file .env.local --profile desarrollo up --build desarrollo
```

No ejecutes app y desarrollo simultáneamente en el mismo puerto. Consulta [docs/docker.md](docs/docker.md) para sincronizar dependencias, compartir una imagen y probar en otra PC.

## Ejecutar con Node.js

Usa Node.js 24, ejecuta `npm ci`, configura `.env.local` y ejecuta `npm run dev`. Valida con `npm run typecheck`, `npm test` y `npm run build`. La configuración standalone permite empaquetar el servidor para Docker.

## Supabase y permisos

La aplicación utiliza Supabase remoto; Docker no instala ni migra la base de datos. Sigue [docs/conectar-supabase.md](docs/conectar-supabase.md) para una instalación nueva. En una base existente aplica los SQL pendientes, sin reinstalar el esquema inicial. Las funciones transaccionales y RLS verifican permisos en la base de datos.

- Registro y asignaciones: [docs/usuarios-y-asignaciones.md](docs/usuarios-y-asignaciones.md).
- Tareas y revisión: [supabase/GUIA_ENTREGAS_TAREAS.md](supabase/GUIA_ENTREGAS_TAREAS.md).
- Inventario y solicitudes: [supabase/GUIA_MATERIALES.md](supabase/GUIA_MATERIALES.md).
- Permisos de jefes: [supabase/GUIA_PERMISOS_PROYECTOS.md](supabase/GUIA_PERMISOS_PROYECTOS.md).
- Inversión y ampliaciones: [supabase/GUIA_INVERSION_PRESUPUESTO.md](supabase/GUIA_INVERSION_PRESUPUESTO.md).
- Documentos: [GUIA_DOCUMENTOS.md](GUIA_DOCUMENTOS.md).
- Pruebas con usuarios reales: [docs/pruebas-piloto.md](docs/pruebas-piloto.md).

`.env.local` y las claves reales están excluidos de Git y de las imágenes Docker. SUPABASE_SECRET_KEY es solo del servidor. Las variables NEXT_PUBLIC se incluyen en la compilación y son públicas. La vista `/vista-previa` permite recorrer las interfaces sin guardar datos.

`dist/` conserva el prototipo HTML original; la aplicación actual está en `src/`.
