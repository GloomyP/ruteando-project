-- Esquema base para Ruteando con Supabase Auth + Supabase REST.
-- Ejecutar en Supabase SQL Editor antes de desplegar a produccion.

create table if not exists public.empresas (
  id text primary key,
  nombre text,
  rut text,
  correo text,
  telefono text,
  direccion text,
  admin_email text,
  admin_uid text,
  actualizado timestamptz default now()
);

create table if not exists public.usuarios_empresas (
  id text primary key,
  empresa_key text not null references public.empresas(id) on delete cascade,
  "empresaKey" text,
  actualizado timestamptz default now()
);

create table if not exists public.roles_usuarios (
  id text primary key,
  rol text not null default 'admin',
  deshabilitado boolean not null default false,
  "debeCambiarContrasena" boolean not null default false,
  "contrasenaTemporalVisible" text,
  actualizado timestamptz default now()
);

create table if not exists public.perfiles_usuarios (
  id text primary key,
  nombre text,
  email text,
  telefono text,
  region text,
  comuna text,
  direccion text,
  actualizado timestamptz default now()
);

create table if not exists public.conductores_empresas (
  id text primary key,
  lista jsonb not null default '[]'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.rutas_asignadas (
  id text primary key,
  email text,
  ruta jsonb not null default '{}'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.notificaciones_rutas (
  id text primary key,
  email text,
  notificacion jsonb not null default '{}'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.notificaciones_internas (
  id text primary key,
  lista jsonb not null default '[]'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.asignaciones_globales (
  id text primary key,
  lista jsonb not null default '[]'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.historial_rutas_terminadas (
  id text primary key,
  lista jsonb not null default '[]'::jsonb,
  actualizado timestamptz default now()
);

create table if not exists public.inventario_productos (
  empresa_key text not null,
  id text not null,
  nombre text,
  categoria text,
  descripcion text,
  "stockActual" integer not null default 0,
  "stockMinimo" integer not null default 0,
  unidad text,
  estado text,
  actualizado timestamptz default now(),
  primary key (empresa_key, id)
);

create table if not exists public.inventario_stock_repartidores (
  empresa_key text not null,
  id text not null,
  nombre text,
  email text,
  "bidonesCargados" integer not null default 0,
  "bidonesEntregados" integer not null default 0,
  "bidonesRetornados" integer not null default 0,
  "bidonesDanados" integer not null default 0,
  "stockPendiente" integer not null default 0,
  actualizado timestamptz default now(),
  primary key (empresa_key, id)
);

create table if not exists public.inventario_movimientos (
  empresa_key text not null,
  id text not null,
  "productoId" text,
  "productoNombre" text,
  tipo text,
  cantidad integer not null default 0,
  responsable text,
  email text,
  observacion text,
  fecha timestamptz,
  primary key (empresa_key, id)
);

-- ============================================================
-- SEGURIDAD PRODUCCION
-- ============================================================

insert into public.roles_usuarios (
  id,
  rol,
  deshabilitado,
  "debeCambiarContrasena",
  "contrasenaTemporalVisible",
  actualizado
) values (
  'admin@ruteando.cl',
  'admin',
  false,
  false,
  null,
  now()
) on conflict (id) do update set
  rol = excluded.rol,
  deshabilitado = excluded.deshabilitado,
  "debeCambiarContrasena" = excluded."debeCambiarContrasena",
  actualizado = now();

insert into public.perfiles_usuarios (
  id,
  nombre,
  email,
  actualizado
) values (
  'admin@ruteando.cl',
  'Administrador Ruteando',
  'admin@ruteando.cl',
  now()
) on conflict (id) do update set
  nombre = excluded.nombre,
  email = excluded.email,
  actualizado = now();

create or replace function public.ruteando_usuario_email()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.email(), ''));
$$;

create or replace function public.ruteando_es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.roles_usuarios
    where id = public.ruteando_usuario_email()
      and rol = 'admin'
      and deshabilitado = false
  );
$$;

grant execute on function public.ruteando_usuario_email() to authenticated;
grant execute on function public.ruteando_es_admin() to authenticated;

grant select, insert, update, delete on public.empresas to authenticated;
grant select, insert, update, delete on public.usuarios_empresas to authenticated;
grant select, insert, update, delete on public.roles_usuarios to authenticated;
grant select, insert, update, delete on public.perfiles_usuarios to authenticated;
grant select, insert, update, delete on public.conductores_empresas to authenticated;
grant select, insert, update, delete on public.rutas_asignadas to authenticated;
grant select, insert, update, delete on public.notificaciones_rutas to authenticated;
grant select, insert, update, delete on public.notificaciones_internas to authenticated;
grant select, insert, update, delete on public.asignaciones_globales to authenticated;
grant select, insert, update, delete on public.historial_rutas_terminadas to authenticated;
grant select, insert, update, delete on public.inventario_productos to authenticated;
grant select, insert, update, delete on public.inventario_stock_repartidores to authenticated;
grant select, insert, update, delete on public.inventario_movimientos to authenticated;

alter table public.empresas enable row level security;
alter table public.usuarios_empresas enable row level security;
alter table public.roles_usuarios enable row level security;
alter table public.perfiles_usuarios enable row level security;
alter table public.conductores_empresas enable row level security;
alter table public.rutas_asignadas enable row level security;
alter table public.notificaciones_rutas enable row level security;
alter table public.notificaciones_internas enable row level security;
alter table public.asignaciones_globales enable row level security;
alter table public.historial_rutas_terminadas enable row level security;
alter table public.inventario_productos enable row level security;
alter table public.inventario_stock_repartidores enable row level security;
alter table public.inventario_movimientos enable row level security;

drop policy if exists "empresas_admin_total" on public.empresas;
create policy "empresas_admin_total" on public.empresas
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "empresas_usuario_lectura" on public.empresas;
create policy "empresas_usuario_lectura" on public.empresas
  for select to authenticated
  using (
    public.ruteando_es_admin()
    or exists (
      select 1 from public.usuarios_empresas ue
      where ue.id = public.ruteando_usuario_email()
        and ue.empresa_key = empresas.id
    )
  );

drop policy if exists "usuarios_empresas_admin_total" on public.usuarios_empresas;
create policy "usuarios_empresas_admin_total" on public.usuarios_empresas
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "usuarios_empresas_usuario_lectura" on public.usuarios_empresas;
create policy "usuarios_empresas_usuario_lectura" on public.usuarios_empresas
  for select to authenticated
  using (id = public.ruteando_usuario_email() or public.ruteando_es_admin());

drop policy if exists "roles_admin_total" on public.roles_usuarios;
create policy "roles_admin_total" on public.roles_usuarios
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "roles_usuario_lectura" on public.roles_usuarios;
create policy "roles_usuario_lectura" on public.roles_usuarios
  for select to authenticated
  using (id = public.ruteando_usuario_email() or public.ruteando_es_admin());

drop policy if exists "roles_usuario_registro_repartidor" on public.roles_usuarios;
create policy "roles_usuario_registro_repartidor" on public.roles_usuarios
  for insert to authenticated
  with check (
    id = public.ruteando_usuario_email()
    and rol = 'repartidor'
    and deshabilitado = false
  );

drop policy if exists "perfiles_usuario_total" on public.perfiles_usuarios;
create policy "perfiles_usuario_total" on public.perfiles_usuarios
  for all to authenticated
  using (id = public.ruteando_usuario_email() or public.ruteando_es_admin())
  with check (id = public.ruteando_usuario_email() or public.ruteando_es_admin());

drop policy if exists "conductores_admin_total" on public.conductores_empresas;
create policy "conductores_admin_total" on public.conductores_empresas
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "rutas_admin_total" on public.rutas_asignadas;
create policy "rutas_admin_total" on public.rutas_asignadas
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "rutas_conductor_propia" on public.rutas_asignadas;
create policy "rutas_conductor_propia" on public.rutas_asignadas
  for all to authenticated
  using (lower(coalesce(email, id)) = public.ruteando_usuario_email())
  with check (lower(coalesce(email, id)) = public.ruteando_usuario_email());

drop policy if exists "notificaciones_rutas_admin_total" on public.notificaciones_rutas;
create policy "notificaciones_rutas_admin_total" on public.notificaciones_rutas
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "notificaciones_rutas_conductor_propia" on public.notificaciones_rutas;
create policy "notificaciones_rutas_conductor_propia" on public.notificaciones_rutas
  for all to authenticated
  using (lower(coalesce(email, id)) = public.ruteando_usuario_email())
  with check (lower(coalesce(email, id)) = public.ruteando_usuario_email());

drop policy if exists "notificaciones_internas_usuario" on public.notificaciones_internas;
create policy "notificaciones_internas_usuario" on public.notificaciones_internas
  for all to authenticated
  using (id = public.ruteando_usuario_email() or public.ruteando_es_admin())
  with check (id = public.ruteando_usuario_email() or public.ruteando_es_admin());

drop policy if exists "asignaciones_admin_total" on public.asignaciones_globales;
create policy "asignaciones_admin_total" on public.asignaciones_globales
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "historial_autenticados" on public.historial_rutas_terminadas;
create policy "historial_autenticados" on public.historial_rutas_terminadas
  for all to authenticated
  using (public.ruteando_es_admin() or id = public.ruteando_usuario_email())
  with check (public.ruteando_es_admin() or id = public.ruteando_usuario_email());

drop policy if exists "inventario_productos_admin_total" on public.inventario_productos;
create policy "inventario_productos_admin_total" on public.inventario_productos
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "inventario_stock_admin_total" on public.inventario_stock_repartidores;
create policy "inventario_stock_admin_total" on public.inventario_stock_repartidores
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());

drop policy if exists "inventario_movimientos_admin_total" on public.inventario_movimientos;
create policy "inventario_movimientos_admin_total" on public.inventario_movimientos
  for all to authenticated
  using (public.ruteando_es_admin())
  with check (public.ruteando_es_admin());
