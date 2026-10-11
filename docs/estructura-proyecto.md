# Estructura propuesta para la aplicación final

La base implementada utiliza `src/app`, `src/components`, `src/features` y
`src/lib`. Cada funcionalidad separa `domain`, `application` e `infrastructure`
cuando existe código para esa capa. La renovación de sesión usa `src/proxy.ts`
de Next.js 16. Ver `arquitectura.md` para el alcance actual; el árbol siguiente
representa la propuesta original, no el inventario de archivos implementados.

La implementación definitiva utilizará Next.js con una organización por
funcionalidad. Cada módulo agrupa su interfaz, validaciones y acceso a datos para
evitar que el proyecto se convierta en una colección de archivos sin relación.

```text
gestion-proyectos/
├── app/
│   ├── (auth)/
│   │   ├── iniciar-sesion/
│   │   └── recuperar-clave/
│   ├── (dashboard)/
│   │   ├── page.tsx
│   │   ├── proyectos/
│   │   ├── tareas/
│   │   ├── materiales/
│   │   ├── aprobaciones/
│   │   ├── diagramas/
│   │   ├── reportes/
│   │   └── administracion/
│   ├── api/
│   │   ├── emails/
│   │   └── webhooks/
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── ui/
│   ├── layout/
│   ├── shared/
│   └── charts/
├── features/
│   ├── projects/
│   ├── tasks/
│   ├── materials/
│   ├── approvals/
│   ├── reports/
│   └── diagrams/
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   ├── server.ts
│   │   └── middleware.ts
│   ├── permissions/
│   ├── email/
│   ├── validations/
│   └── utils/
├── types/
├── emails/
├── public/
├── supabase/
│   ├── migrations/
│   ├── seed.sql
│   └── tests/
├── tests/
├── docs/
├── middleware.ts
├── .env.example
└── README.md
```

## Responsabilidad de cada nivel

- `app/`: rutas, páginas, layouts y puntos de entrada del servidor.
- `features/`: reglas e interfaz propias de cada módulo de negocio.
- `components/ui/`: controles visuales reutilizables y sin lógica de negocio.
- `components/layout/`: barra lateral, encabezado y estructura de páginas.
- `lib/supabase/`: conexiones seguras para navegador y servidor.
- `lib/permissions/`: comprobaciones de rol, permiso y alcance.
- `emails/`: plantillas que se enviarán mediante Resend.
- `supabase/migrations/`: versión reproducible de tablas, funciones y políticas RLS.
- `supabase/tests/`: pruebas de acceso permitido y denegado para cada rol.
- `docs/`: decisiones funcionales, casos de uso y diagramas del sistema.

## Convenciones

- Carpetas y archivos técnicos en inglés; textos de interfaz en español.
- Componentes React en `PascalCase`; funciones y variables en `camelCase`.
- Las consultas de datos no se escriben directamente dentro de componentes visuales.
- Toda tabla expuesta por Supabase debe tener permisos mínimos y políticas RLS.
- Las claves privadas de Supabase y Resend solo se utilizan en el servidor.
- Cada cambio de base de datos debe registrarse como una migración.
