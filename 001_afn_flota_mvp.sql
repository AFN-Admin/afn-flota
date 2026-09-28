create extension if not exists pgcrypto;

create type public.app_role as enum ('OPERATOR','COMPANY_ADMIN','AUTHORIZED_ANALYST','AFN_ADMIN');
create type public.fuel_load_status as enum ('PENDING_SYNC','PENDING_VALIDATION','VALIDATED','OBSERVED','CORRECTED');
create type public.evidence_type as enum ('DASHBOARD_POST_FUEL','FUEL_TICKET');

create table public.companies (
  id uuid primary key default gen_random_uuid(), name text not null, plan_code text not null default 'FREE', created_at timestamptz not null default now()
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade, company_id uuid references public.companies(id), full_name text not null, role public.app_role not null default 'OPERATOR', active boolean not null default true, created_at timestamptz not null default now()
);
create table public.vehicles (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), unit_code text not null, plates text, fuel_type text not null, active boolean not null default true, created_at timestamptz not null default now(), unique(company_id, unit_code)
);
create table public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id), operator_id uuid not null references public.profiles(id), starts_at timestamptz not null default now(), ends_at timestamptz, active boolean not null default true
);
create table public.fuel_loads (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), vehicle_id uuid not null references public.vehicles(id), registered_by uuid not null references public.profiles(id), station_name text not null, fuel_type text not null, liters numeric(12,3) not null check (liters > 0), price_per_liter numeric(12,3) not null check (price_per_liter > 0), total_amount numeric(14,2) generated always as (round((liters * price_per_liter)::numeric,2)) stored, odometer_km integer not null check (odometer_km >= 0), captured_at timestamptz not null, received_at timestamptz, latitude numeric(10,7), longitude numeric(10,7), status public.fuel_load_status not null default 'PENDING_SYNC', created_at timestamptz not null default now()
);
create table public.evidences (
  id uuid primary key default gen_random_uuid(), fuel_load_id uuid not null references public.fuel_loads(id) on delete restrict, type public.evidence_type not null, storage_path text not null, sha256 text not null, captured_at timestamptz not null, latitude numeric(10,7), longitude numeric(10,7), device_id text, created_at timestamptz not null default now(), unique(fuel_load_id,type)
);
create table public.alerts (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id), fuel_load_id uuid references public.fuel_loads(id), severity text not null check (severity in ('LOW','MEDIUM','HIGH','CRITICAL')), status text not null default 'OPEN', rule_code text not null, detail text not null, created_at timestamptz not null default now()
);
create table public.audit_log (
  id uuid primary key default gen_random_uuid(), company_id uuid references public.companies(id), actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_assignments enable row level security;
alter table public.fuel_loads enable row level security;
alter table public.evidences enable row level security;
alter table public.alerts enable row level security;
alter table public.audit_log enable row level security;

create function public.current_company_id() returns uuid language sql stable security definer set search_path = public as $$ select company_id from public.profiles where id = auth.uid() $$;
create function public.current_role() returns public.app_role language sql stable security definer set search_path = public as $$ select role from public.profiles where id = auth.uid() $$;

create policy "profiles own company" on public.profiles for select using (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN');
create policy "vehicles company read" on public.vehicles for select using (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN');
create policy "vehicles company admin write" on public.vehicles for all using (public.current_role() in ('COMPANY_ADMIN','AFN_ADMIN') and (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN'));
create policy "loads company read" on public.fuel_loads for select using (company_id = public.current_company_id() or registered_by = auth.uid() or public.current_role() = 'AFN_ADMIN');
create policy "loads operator insert" on public.fuel_loads for insert with check (registered_by = auth.uid() and company_id = public.current_company_id());
create policy "alerts company read" on public.alerts for select using (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN');
create policy "audit admin read" on public.audit_log for select using ((company_id = public.current_company_id() and public.current_role() in ('COMPANY_ADMIN','AUTHORIZED_ANALYST')) or public.current_role() = 'AFN_ADMIN');

create index fuel_loads_company_created_idx on public.fuel_loads(company_id, created_at desc);
create index fuel_loads_vehicle_captured_idx on public.fuel_loads(vehicle_id, captured_at desc);
