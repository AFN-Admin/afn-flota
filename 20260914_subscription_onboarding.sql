-- Onboarding comercial AFN Flota: estados de cobro y activación de cuenta.
alter table public.companies
  add column if not exists account_status text not null default 'ACTIVE',
  add column if not exists payment_status text not null default 'NOT_REQUIRED',
  add column if not exists special_requirements text,
  add column if not exists mercadopago_preference_id text,
  add column if not exists mercadopago_payment_id text;

alter table public.companies
  drop constraint if exists companies_account_status_check;
alter table public.companies
  add constraint companies_account_status_check
  check (account_status in ('ACTIVE','PENDING_PAYMENT','PENDING_QUOTE','INACTIVE'));

alter table public.companies
  drop constraint if exists companies_payment_status_check;
alter table public.companies
  add constraint companies_payment_status_check
  check (payment_status in ('NOT_REQUIRED','PENDING','PAID','REJECTED','QUOTE_PENDING'));

create index if not exists companies_account_status_idx on public.companies(account_status);
