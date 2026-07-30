-- CRM Broker Seguros — MC Asesores de Seguros
-- Run this once in the Supabase project's SQL editor (Dashboard > SQL Editor > New query).
-- Safe to re-run: every statement is idempotent (IF NOT EXISTS / OR REPLACE / DROP ... IF EXISTS).

create extension if not exists pgcrypto;

-- ── profiles ────────────────────────────────────────────────────────────────
-- One row per broker (auth user). Populated automatically when a new
-- auth.users row is created (see the trigger below).
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  iniciales text not null,
  created_at timestamptz not null default now()
);

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into profiles (id, nombre, iniciales)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', new.email),
    coalesce(new.raw_user_meta_data->>'iniciales', upper(left(coalesce(new.email, 'US'), 2)))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── clients ─────────────────────────────────────────────────────────────────
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  apellido text not null,
  nombre text not null,
  tipo_documento text not null default 'DNI',
  dni text not null default '',
  condicion_fiscal text not null default 'Consumidor Final',
  telefono text not null default '',
  email text not null default '',
  fecha_nacimiento date,
  direccion text not null default '',
  provincia text not null default '',
  localidad text not null default '',
  codigo_postal text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── policies (bienes / pólizas, por categoría) ───────────────────────────────
-- type_key: 'auto' | 'inmueble' | 'negocio' | 'consorcio' | 'vidaSalud' | 'art' | 'ap' | 'caucion' | 'tecnico'
-- deleted_at marks a soft-delete: the record moves to "Bienes Anteriores" in the UI.
create table if not exists policies (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  type_key text not null check (type_key in ('auto','inmueble','negocio','consorcio','vidaSalud','art','ap','caucion','tecnico')),
  aseguradora text not null default '',
  n_poliza text not null default '',
  suma_asegurada numeric,
  prima numeric,
  moneda_suma text not null default '$',
  moneda_prima text not null default '$',
  vigencia_desde date,
  vigencia_hasta date,
  cobertura_contratada text not null default '',
  franquicia text not null default '',
  operacion text not null default 'Nuevo',
  forma_pago text not null default 'Efectivo',
  vencimiento_pago_dia text not null default '1',
  details jsonb not null default '{}'::jsonb,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists policies_client_id_idx on policies(client_id);

-- ── quotes (cotizaciones) ─────────────────────────────────────────────────────
create table if not exists quotes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  type_key text not null check (type_key in ('auto','inmueble','negocio','consorcio','vidaSalud','art','ap','caucion','tecnico')),
  bien text not null default '',
  aseguradora text not null default '',
  costo numeric not null default 0,
  fecha date not null default current_date,
  estado text not null default 'Cotizada',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists quotes_client_id_idx on quotes(client_id);

-- ── claims (siniestros) ────────────────────────────────────────────────────
create table if not exists claims (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  type_key text not null,
  fecha date not null,
  estado text not null default 'Abierto',
  descripcion text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists claims_client_id_idx on claims(client_id);

-- ── documents ───────────────────────────────────────────────────────────────
create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  nombre text not null,
  tipo text not null default '',
  fecha date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists documents_client_id_idx on documents(client_id);

-- ── notes (notas internas) ──────────────────────────────────────────────────
create table if not exists notes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null,
  author_name text not null default '',
  text text not null,
  created_at timestamptz not null default now()
);
create index if not exists notes_client_id_idx on notes(client_id);

-- ── task_lists / tasks / task_steps ─────────────────────────────────────────
create table if not exists task_lists (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  created_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  task_list_id uuid not null references task_lists(id) on delete cascade,
  texto text not null,
  hecha boolean not null default false,
  recordatorio date,
  mi_dia boolean not null default false,
  hora_aviso time,
  vence date,
  repetir boolean not null default false,
  asignado_a uuid references profiles(id) on delete set null,
  archivo text not null default '',
  nota text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists tasks_task_list_id_idx on tasks(task_list_id);

create table if not exists task_steps (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references tasks(id) on delete cascade,
  texto text not null,
  hecha boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists task_steps_task_id_idx on task_steps(task_id);

-- ── Row Level Security ───────────────────────────────────────────────────────
-- Shared-book model: any authenticated broker can read/write everything.
-- (All 4+ users see and edit the full client portfolio, matching how the
-- prototype behaves today — just synced across users instead of per-browser.)
alter table profiles enable row level security;
alter table clients enable row level security;
alter table policies enable row level security;
alter table quotes enable row level security;
alter table claims enable row level security;
alter table documents enable row level security;
alter table notes enable row level security;
alter table task_lists enable row level security;
alter table tasks enable row level security;
alter table task_steps enable row level security;

drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select to authenticated using (true);
drop policy if exists profiles_update_own on profiles;
create policy profiles_update_own on profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

do $$
declare
  t text;
begin
  foreach t in array array['clients','policies','quotes','claims','documents','notes','task_lists','tasks','task_steps']
  loop
    execute format('drop policy if exists %I_all on %I;', t, t);
    execute format(
      'create policy %I_all on %I for all to authenticated using (true) with check (true);',
      t, t
    );
  end loop;
end $$;

-- ── Realtime ─────────────────────────────────────────────────────────────────
-- Adds each table to the publication Supabase Realtime streams from.
-- (Ignore "already a member" notices if you re-run this script.)
do $$
declare
  t text;
begin
  foreach t in array array['clients','policies','quotes','claims','documents','notes','task_lists','tasks','task_steps','profiles']
  loop
    begin
      execute format('alter publication supabase_realtime add table %I;', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;
