-- Registro autónomo para la beta Free.
-- Crea una empresa Free y su primer administrador únicamente cuando el alta
-- proviene del formulario público identificado como FREE_BETA.

alter table public.profiles
  add column if not exists email text;

alter table public.companies
  add column if not exists legal_name text,
  add column if not exists business_activity text,
  add column if not exists state text,
  add column if not exists address text,
  add column if not exists contact_name text,
  add column if not exists contact_position text,
  add column if not exists contact_email text,
  add column if not exists contact_phone text,
  add column if not exists account_status text not null default 'ACTIVE',
  add column if not exists payment_status text not null default 'NOT_REQUIRED';

create or replace function public.create_free_beta_company()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  new_company_id uuid;
  company_name text := trim(coalesce(new.raw_user_meta_data ->> 'company_name', ''));
  administrator_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
begin
  if coalesce(new.raw_user_meta_data ->> 'onboarding_source', '') <> 'FREE_BETA' then
    return new;
  end if;

  if company_name = '' or administrator_name = '' then
    raise exception 'El registro Free requiere nombre de empresa y administrador.'
      using errcode = 'P0001';
  end if;

  insert into public.companies (
    name,
    legal_name,
    business_activity,
    state,
    address,
    contact_name,
    contact_position,
    contact_email,
    contact_phone,
    plan_code,
    account_status,
    payment_status
  ) values (
    company_name,
    company_name,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'business_activity', '')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'state', '')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'address', '')), ''),
    administrator_name,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'contact_position', '')), ''),
    new.email,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), ''),
    'FREE',
    'ACTIVE',
    'NOT_REQUIRED'
  ) returning id into new_company_id;

  insert into public.profiles (id, company_id, full_name, email, role, active)
  values (new.id, new_company_id, administrator_name, new.email, 'COMPANY_ADMIN', true);

  return new;
end;
$$;

drop trigger if exists create_free_beta_company_after_signup on auth.users;
create trigger create_free_beta_company_after_signup
after insert on auth.users
for each row execute function public.create_free_beta_company();
