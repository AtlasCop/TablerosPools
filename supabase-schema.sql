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
  "quoteCategory" text,
  "createdAt" bigint
);
create index if not exists items_category_idx on items ("categoryId");

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
  phone text
);
-- Por si la tabla ya existía de una corrida anterior de este script:
alter table kanban_members add column if not exists phone text;

-- ------------------------------------------------------------
-- Acceso: el login de la app es solo una pantalla local (no hay
-- autenticación real contra Supabase), así que se deja la clave
-- publicable con permiso total de lectura/escritura sobre estas
-- tablas. Cualquiera que tenga esa clave podría leer/escribir
-- directo a la base de datos sin pasar por el login — ver el
-- README del proyecto para el detalle de esta limitación.
-- ------------------------------------------------------------
alter table items enable row level security;
alter table counters enable row level security;
alter table quotes enable row level security;
alter table kanban_tasks enable row level security;
alter table kanban_members enable row level security;

drop policy if exists "allow all - items" on items;
create policy "allow all - items" on items for all to anon, authenticated using (true) with check (true);

drop policy if exists "allow all - counters" on counters;
create policy "allow all - counters" on counters for all to anon, authenticated using (true) with check (true);

drop policy if exists "allow all - quotes" on quotes;
create policy "allow all - quotes" on quotes for all to anon, authenticated using (true) with check (true);

drop policy if exists "allow all - kanban_tasks" on kanban_tasks;
create policy "allow all - kanban_tasks" on kanban_tasks for all to anon, authenticated using (true) with check (true);

drop policy if exists "allow all - kanban_members" on kanban_members;
create policy "allow all - kanban_members" on kanban_members for all to anon, authenticated using (true) with check (true);
