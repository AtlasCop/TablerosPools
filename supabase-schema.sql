-- ============================================================
-- Aqua Bruma — esquema de base de datos en Supabase
-- Pega TODO este archivo en Supabase → SQL Editor → "New query"
-- y dale RUN una sola vez. Es seguro volver a correrlo (usa
-- "if not exists" y "or replace").
-- ============================================================

-- Inventario real (objetos por categoría)
create table if not exists items (
  id text primary key,
  "categoryId" text not null,
  code text not null,
  name text not null,
  subline text,
  description text,
  "priceNoTax" numeric,
  "imageDataUrl" text,
  "image3DDataUrl" text,
  "quoteCategory" text,
  "createdAt" bigint
);
create index if not exists items_category_idx on items ("categoryId");
-- Por si la tabla ya existía de una corrida anterior de este script:
alter table items add column if not exists "image3DDataUrl" text;

-- Contador para el código autoincremental por categoría (ej. MB-0001)
create table if not exists counters (
  "categoryId" text primary key,
  last integer not null default 0
);

-- Función atómica que entrega el siguiente código ya formateado
create or replace function next_code(p_category_id text, p_prefix text)
returns text
language plpgsql
as $$
declare
  v_last integer;
begin
  insert into counters ("categoryId", last) values (p_category_id, 1)
  on conflict ("categoryId") do update set last = counters.last + 1
  returning last into v_last;
  return p_prefix || '-' || lpad(v_last::text, 4, '0');
end;
$$;

-- Historial de cotizaciones generadas (Panel Cotizaciones)
create table if not exists quotes (
  id text primary key,
  "createdAt" bigint,
  "boardName" text,
  "clientName" text,
  "clientCompany" text,
  "clientPhone" text,
  "clientEmail" text,
  "clientProject" text,
  "clientNote" text,
  categories jsonb,
  "grandTotal" numeric,
  status text default 'pendiente',
  "ownerId" text,
  "ownerName" text,
  "ownerPhone" text
);
-- Por si la tabla ya existía de una corrida anterior de este script:
alter table quotes add column if not exists "ownerId" text;
alter table quotes add column if not exists "ownerName" text;
alter table quotes add column if not exists "ownerPhone" text;

-- Tareas del Tablero Kanban
create table if not exists kanban_tasks (
  id text primary key,
  title text not null,
  description text,
  "assigneeId" text,
  priority text default 'media',
  "dueDate" text,
  "column" text default 'todo',
  "createdAt" bigint
);

-- Equipo de trabajo (personas asignables en el Kanban y responsables de cotizaciones)
create table if not exists kanban_members (
  id text primary key,
  name text not null,
  color text,
  phone text,
  "photoDataUrl" text,
  role text
);
-- Por si la tabla ya existía de una corrida anterior de este script:
alter table kanban_members add column if not exists phone text;
alter table kanban_members add column if not exists "photoDataUrl" text;
alter table kanban_members add column if not exists role text;

-- Comentarios de actualización de cada tarea del Kanban (una fila por
-- comentario, no un arreglo dentro de la tarea, para que dos personas
-- comentando casi al tiempo no se pisen el trabajo entre sí)
create table if not exists kanban_comments (
  id text primary key,
  "taskId" text not null,
  "authorId" text,
  text text not null,
  "createdAt" bigint
);
create index if not exists kanban_comments_task_idx on kanban_comments ("taskId");

-- Tablero 3D: una sola "sala" compartida por todo el equipo (medidas
-- reales del cuarto de máquinas + los equipos colocados en ella).
create table if not exists room3d (
  id text primary key default 'default',
  width numeric default 4,
  depth numeric default 3,
  height numeric default 2.5,
  objects jsonb default '[]'::jsonb
);
insert into room3d (id) values ('default') on conflict (id) do nothing;

-- ============================================================
-- USUARIOS REALES, APROBACIÓN Y ROLES
-- Reemplaza el login local por autenticación real de Supabase
-- (correo + contraseña). Quien se registra queda "pending" y sin
-- acceso a nada hasta que un administrador lo apruebe y le asigne
-- un rol. Los permisos de abajo se hacen cumplir en la base de
-- datos (RLS), no solo ocultando botones en la pantalla.
-- ============================================================

-- Un perfil por cada cuenta de auth.users — guarda su estado de
-- aprobación y su rol. role: 'consulta' | 'editor' | 'admin'.
-- status: 'pending' | 'approved' | 'rejected'.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'consulta',
  status text not null default 'pending',
  "createdAt" timestamptz not null default now()
);

-- Crea el perfil automáticamente cuando alguien se registra
-- (security definer: corre con privilegios elevados para poder
-- insertar en profiles pasando por encima de sus propias políticas).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role, status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''), 'consulta', 'pending');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Rol del usuario actual, solo si ya fue aprobado (NULL si está
-- pendiente/rechazado o no tiene sesión) — security definer para
-- poder leer profiles sin caer en las políticas de profiles mismas
-- (evita recursión) y para que las demás tablas puedan usarla.
create or replace function public.current_user_role()
returns text
language sql
security definer
stable
as $$
  select role from public.profiles where id = auth.uid() and status = 'approved';
$$;

alter table profiles enable row level security;
drop policy if exists "leer mi propio perfil" on profiles;
create policy "leer mi propio perfil" on profiles for select
  to authenticated using (id = auth.uid());
drop policy if exists "admins leen todos los perfiles" on profiles;
create policy "admins leen todos los perfiles" on profiles for select
  to authenticated using (public.current_user_role() = 'admin');
drop policy if exists "admins actualizan perfiles" on profiles;
create policy "admins actualizan perfiles" on profiles for update
  to authenticated using (public.current_user_role() = 'admin');

-- ------------------------------------------------------------
-- Permisos por tabla — ver el mapa de roles en el README/memoria
-- del proyecto. Regla general: cualquier usuario aprobado puede
-- LEER todo; crear/editar/eliminar requiere admin o editor, EXCEPTO
-- cotizaciones, donde "consulta" también puede crear/ver/cambiar
-- estado (pero no eliminar).
-- ------------------------------------------------------------
alter table items enable row level security;
alter table counters enable row level security;
alter table quotes enable row level security;
alter table kanban_tasks enable row level security;
alter table kanban_members enable row level security;
alter table room3d enable row level security;
alter table kanban_comments enable row level security;

-- items (inventario)
drop policy if exists "allow all - items" on items;
drop policy if exists "items: leer" on items;
create policy "items: leer" on items for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "items: escribir" on items;
create policy "items: escribir" on items for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- counters (soporte del código automático — mismos permisos que items)
drop policy if exists "allow all - counters" on counters;
drop policy if exists "counters: escribir" on counters;
create policy "counters: escribir" on counters for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- quotes (cotizaciones) — "consulta" también puede crear/ver/actualizar
drop policy if exists "allow all - quotes" on quotes;
drop policy if exists "quotes: leer" on quotes;
create policy "quotes: leer" on quotes for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "quotes: crear" on quotes;
create policy "quotes: crear" on quotes for insert to authenticated
  with check (public.current_user_role() in ('admin', 'editor', 'consulta'));
drop policy if exists "quotes: actualizar" on quotes;
create policy "quotes: actualizar" on quotes for update to authenticated
  using (public.current_user_role() in ('admin', 'editor', 'consulta'))
  with check (public.current_user_role() in ('admin', 'editor', 'consulta'));
drop policy if exists "quotes: eliminar" on quotes;
create policy "quotes: eliminar" on quotes for delete to authenticated
  using (public.current_user_role() in ('admin', 'editor'));

-- kanban_tasks
drop policy if exists "allow all - kanban_tasks" on kanban_tasks;
drop policy if exists "kanban_tasks: leer" on kanban_tasks;
create policy "kanban_tasks: leer" on kanban_tasks for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "kanban_tasks: escribir" on kanban_tasks;
create policy "kanban_tasks: escribir" on kanban_tasks for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- kanban_members (equipo)
drop policy if exists "allow all - kanban_members" on kanban_members;
drop policy if exists "kanban_members: leer" on kanban_members;
create policy "kanban_members: leer" on kanban_members for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "kanban_members: escribir" on kanban_members;
create policy "kanban_members: escribir" on kanban_members for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- kanban_comments
drop policy if exists "allow all - kanban_comments" on kanban_comments;
drop policy if exists "kanban_comments: leer" on kanban_comments;
create policy "kanban_comments: leer" on kanban_comments for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "kanban_comments: escribir" on kanban_comments;
create policy "kanban_comments: escribir" on kanban_comments for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- room3d (tablero 3D)
drop policy if exists "allow all - room3d" on room3d;
drop policy if exists "room3d: leer" on room3d;
create policy "room3d: leer" on room3d for select to authenticated using (public.current_user_role() is not null);
drop policy if exists "room3d: escribir" on room3d;
create policy "room3d: escribir" on room3d for all to authenticated
  using (public.current_user_role() in ('admin', 'editor'))
  with check (public.current_user_role() in ('admin', 'editor'));

-- ============================================================
-- PASO MANUAL, UNA SOLA VEZ: crear el primer administrador
-- ============================================================
-- Nadie puede aprobarse a sí mismo, así que el primer administrador
-- hay que crearlo a mano aquí. Pasos:
--   1. Corre TODO lo de arriba de este archivo primero (Run).
--   2. Ve a la app (index.html) y REGÍSTRATE normalmente con tu
--      correo real — quedará "pendiente", es normal.
--   3. Reemplaza el correo en la línea de abajo por el tuyo, borra
--      los guiones "--" que la comentan, y corre SOLO esa línea
--      (selecciónala y dale Run, o corre todo el archivo de nuevo).
--
-- update public.profiles set role = 'admin', status = 'approved' where email = 'tu-correo@ejemplo.com';
--
-- De ahí en adelante, ya puedes aprobar a los demás desde la
-- pestaña "Usuarios" de la app, sin volver a tocar SQL.
