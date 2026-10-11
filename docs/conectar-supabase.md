# Instalar Nexo en Supabase y conectar la web

## 1. Crear el proyecto

Crea un proyecto Supabase desde su dashboard. Supabase proporciona la base de
datos PostgreSQL, Auth, Storage y los roles de API; no ejecutes CREATE DATABASE.
Usa un proyecto nuevo para esta instalación inicial.

## 2. Crear las tablas

Abre SQL Editor, crea una consulta, pega TODO el contenido de
`supabase/01_instalar_nexo.sql` y ejecuta Run con el rol postgres.

El archivo incluye tablas, relaciones, índices, catálogos, triggers, permisos,
políticas RLS, vistas para reportes y el bucket privado `project-files`.
La instalación se ejecuta dentro de una transacción. Está prevista para una sola
ejecución en una base nueva; no borra ni reemplaza tablas existentes. Si ya
aplicaste la migración inicial, omite este paso: es el mismo esquema.

El archivo es una copia de entrega de la migración
`supabase/migrations/20260920000000_initial_schema.sql`.
Conserva las migraciones como fuente para cambios futuros. No ejecutes ambos
archivos contra la misma base ni apliques después la migración inicial por CLI
sin reconciliar antes el historial de migraciones.

## 3. Crear el administrador

En Authentication > Users crea un usuario con correo y contraseña. Confirma su
correo mediante la opción del dashboard o el flujo de confirmación disponible.

Abre `supabase/02_crear_administrador.sql`, reemplaza
`CAMBIAR_POR_TU_CORREO` y, si deseas, el nombre y slug de la organización.
Ejecuta el archivo en SQL Editor como postgres. Creará la organización, sus
siete roles, permisos y la asignación de administrador. Puede repetirse para el
mismo usuario y slug sin crear otra organización.

Ejecuta `supabase/03_verificar_instalacion.sql` para revisar tablas, RLS,
bucket y roles. Estas consultas no sustituyen pruebas de acceso con varios usuarios.

## 4. Conectar la web

Obtén Project URL y Publishable key desde Connect del proyecto.
Completa `.env.local` en la raíz del proyecto:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://TU_PROYECTO.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```

La clave es la publishable pública; no uses secret ni service_role en variables
NEXT_PUBLIC. La contraseña PostgreSQL no se necesita en la aplicación actual.
Las dos variables ya están conectadas con los clientes Supabase del servidor y
navegador. No hace falta escribir una API adicional para las consultas actuales.

En la configuración de URLs de Authentication usa `http://localhost:3000` como
Site URL para desarrollo. `supabase/config.toml` configura el entorno local de
CLI, no cambia automáticamente los ajustes del proyecto remoto.

Ejecuta `npm run dev`; si ya estaba ejecutándose, reinícialo después de guardar
las variables. Abre http://localhost:3000/iniciar-sesion e ingresa con el usuario
administrador. Las listas estarán vacías hasta registrar datos.

`.env.local` está excluido de Git. Para desplegar, configura esas mismas variables
en el proveedor de hosting y actualiza la URL de Authentication al dominio real.

## Alcance

Los archivos preparan el esquema para los módulos definidos. La web actual tiene
autenticación y consultas; aún faltan formularios y operaciones transaccionales
de aprobación, reserva, entrega y devolución. La conexión no implementa esas
acciones automáticamente.

No se ejecutó esta instalación en un proyecto Supabase remoto durante su
preparación. La comprobación real de PostgreSQL y de permisos se realiza después
de ejecutar los scripts en tu proyecto.

Referencia: https://supabase.com/docs/guides/getting-started/quickstarts/nextjs
