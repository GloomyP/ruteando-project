# Ruteando - Optimizacion de Logistica de Ultima Milla

Ruteando es una solucion web/movil en Flutter para planificar, asignar y monitorear rutas de reparto. La aplicacion permite administrar empresas, repartidores, rutas, inventario, asignaciones y notificaciones operativas.

## Equipo de Proyecto - Grupo 12

| Integrante | Rol | Responsabilidad principal |
| --- | --- | --- |
| Julio Vega | Scrum Master | Gestion de agilidad, procesos y facilitacion tecnica |
| Sebastian Rodriguez | Product Owner | Definicion de valor de negocio y priorizacion de backlog |
| Francisca Meyer | Developer | Desarrollo de interfaz y logica de aplicacion |
| Ignacio Mendoza | Developer | Desarrollo de interfaz y logica de aplicacion |

## Backend

La autenticacion y persistencia de datos se gestionan con Supabase:

- Supabase Auth para login/registro.
- Supabase REST para datos de empresas, usuarios, rutas, inventario y notificaciones.
- RLS y politicas de acceso definidas en `supabase_schema.sql`.

Credenciales base:

- Usuario: `admin@ruteando.cl`
- Contrasena: `ruteando2026`

## Desarrollo Local

```powershell
flutter pub get
flutter run -d chrome
```

Si en Windows aparece un error de symlinks, activar Modo Programador:

```powershell
start ms-settings:developers
```

## Despliegue en Vercel

El repo incluye configuracion para Vercel:

- `vercel.json`
- `scripts/vercel_build.sh`
- `.vercelignore`

Configuracion recomendada en Vercel:

- Framework Preset: `Other`
- Build Command: `bash scripts/vercel_build.sh`
- Output Directory: `build/web`
- Install Command: `echo "Flutter dependencies are resolved in build step"`

Variables opcionales en Vercel:

```text
SUPABASE_REST_URL=https://zexfyjefmomuaoamwycw.supabase.co/rest/v1/
SUPABASE_ANON_KEY=sb_publishable_rrx6nMypqyFpVYw76O7rhg_zmj4Uj8o
```

No configurar `SUPABASE_SERVICE_ROLE_KEY` en el frontend ni en Vercel para esta app web.

## Produccion

Antes de desplegar, ejecutar `supabase_schema.sql` en el SQL Editor de Supabase para crear tablas, seed del admin y politicas RLS.

Tambien se debe restringir la API key de Google Maps en Google Cloud para aceptar el dominio de Vercel que se vaya a usar.
