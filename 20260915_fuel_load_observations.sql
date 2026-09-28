create table if not exists public.fuel_load_observations (
  id uuid primary key default gen_random_uuid(),
  fuel_load_id uuid not null references public.fuel_loads(id) on delete cascade,
  company_id uuid not null references public.companies(id),
  observed_by uuid not null references public.profiles(id),
  reason_code text not null check (reason_code in (
    'DASHBOARD_PHOTO_INVALID','TICKET_PHOTO_INVALID','EVIDENCE_INVALID',
    'TIME_MISMATCH','LITERS_VARIANCE','METER_VARIANCE','PRICE_VARIANCE','OTHER'
  )),
  detail text,
  created_at timestamptz not null default now()
);

alter table public.fuel_load_observations enable row level security;

create policy "observation company read" on public.fuel_load_observations
  for select using (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN');

create policy "observation admin insert" on public.fuel_load_observations
  for insert with check (
    company_id = public.current_company_id()
    and public.current_role() in ('COMPANY_ADMIN','AFN_ADMIN')
    and observed_by = auth.uid()
  );

create index if not exists fuel_load_observations_load_idx on public.fuel_load_observations(fuel_load_id, created_at desc);
create index if not exists fuel_load_observations_company_idx on public.fuel_load_observations(company_id, created_at desc);
