# Compartir Nexo con Docker

Cada colaborador instala Docker Desktop y utiliza contenedores Linux. No necesita instalar Node.js, Next.js ni ejecutar npm install en su PC. La primera construcción descarga Node y las dependencias dentro de Docker; después reutiliza capas. Git comparte el código, Docker comparte el entorno. Supabase continúa remoto y requiere conexión a Internet.

## Configuración

Copia `.env.example` a `.env.local` y configura Supabase. El archivo real está excluido de Git y del contexto de construcción de Docker. Las variables NEXT_PUBLIC son públicas y se incluyen en la compilación; SUPABASE_SECRET_KEY solo se entrega al contenedor al arrancar. Para trabajar sin acceso administrativo puedes dejar esa clave vacía, pero no registrar nuevas cuentas desde la aplicación.

## Probar la aplicación compilada

Desde la carpeta del proyecto:

```powershell
docker compose --env-file .env.local up --build -d app
```

Abre http://localhost:3000. Para siguientes arranques, sin cambios de código, no hace falta reconstruir:

```powershell
docker compose --env-file .env.local up -d app
```

Si cambia el código, las dependencias o las variables públicas de Supabase, repite el primer comando. La imagen de producción incluye la aplicación compilada y ejecuta el servidor como usuario sin privilegios de root.

## Colaborar modificando el código

Detén primero la aplicación compilada si usa el mismo puerto:

```powershell
docker compose --env-file .env.local stop app
docker compose --env-file .env.local --profile desarrollo up --build desarrollo
```

Abre http://localhost:3000. El contenedor observa el código de tu carpeta. Sus dependencias y caché están en volúmenes separados, de modo que no utiliza node_modules de Windows. Si un compañero actualiza package-lock.json, sincroniza las dependencias dentro del contenedor:

```powershell
docker compose --env-file .env.local --profile desarrollo run --rm desarrollo npm ci
```

Después reinicia desarrollo. Los tests y TypeScript también pueden ejecutarse dentro del contenedor:

```powershell
docker compose --env-file .env.local --profile desarrollo run --rm desarrollo npm test
docker compose --env-file .env.local --profile desarrollo run --rm desarrollo npm run typecheck
```

## Compartir una imagen ya construida

Si alguien solo va a probar Nexo, puedes entregarle una imagen y evitar que construya el código:

```powershell
docker image save -o nexo-imagen.tar nexo:local
```

En la otra PC:

```powershell
docker image load -i nexo-imagen.tar
docker run --rm --init --env-file .env.local -p 127.0.0.1:3000:3000 nexo:local
```

La imagen construida conserva la URL y clave pública de Supabase utilizadas al compilar. Para otro proyecto Supabase necesitas reconstruirla. La clave secreta se configura por separado en cada equipo autorizado; nunca va dentro de la imagen ni en Git. Una imagen creada en otra arquitectura puede requerir una construcción para la arquitectura del equipo receptor.

## Logs y detención

```powershell
docker compose --env-file .env.local logs -f app
docker compose --env-file .env.local down
```

## Pruebas desde otros equipos

Por defecto, el puerto solo escucha en tu PC. Para una prueba en tu red local, agrega `NEXO_BIND_HOST=0.0.0.0` en `.env.local`, vuelve a crear el contenedor y accede desde otro equipo a `http://IP-DE-TU-PC:3000`. Windows puede requerir autorizar el puerto en el firewall. No es una publicación pública ni una configuración de HTTPS.

Los usuarios finales no necesitan Docker: para pruebas remotas se despliega una sola instancia y se les entrega su URL. Un dominio propio puede incorporarse después; el envío de invitaciones continúa deshabilitado mientras no se configure el servicio de correo.

Estado de verificación: Docker no está instalado en el equipo donde se preparó esta configuración; hay que ejecutar la primera construcción para validar el contenedor. La compilación standalone se verifica por separado con Next.js.
