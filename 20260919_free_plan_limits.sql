-- Límites del plan Free beta: 2 unidades activas, 2 operadores activos y
-- 10 cargas por mes calendario (zona horaria de Ciudad de México).
-- Los demás planes quedan sin estos topes en esta etapa.

create or replace function public.is_free_plan_company(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select upper(plan_code) = 'FREE' from public.companies where id = target_company_id),
    true
  );
$$;

create or replace function public.enforce_free_vehicle_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_units integer;
begin
  if new.active and public.is_free_plan_company(new.company_id) then
    select count(*) into active_units
    from public.vehicles
    where company_id = new.company_id
      and active
      and id is distinct from new.id;

    if active_units >= 2 then
      raise exception 'El plan Free permite hasta 2 vehículos o maquinaria activos.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_free_vehicle_limit on public.vehicles;
create trigger enforce_free_vehicle_limit
before insert or update of company_id, active on public.vehicles
for each row execute function public.enforce_free_vehicle_limit();

create or replace function public.enforce_free_operator_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_operators integer;
begin
  if new.role = 'OPERATOR' and new.active and public.is_free_plan_company(new.company_id) then
    select count(*) into active_operators
    from public.profiles
    where company_id = new.company_id
      and role = 'OPERATOR'
      and active
      and id is distinct from new.id;

    if active_operators >= 2 then
      raise exception 'El plan Free permite hasta 2 operadores activos.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_free_operator_limit on public.profiles;
create trigger enforce_free_operator_limit
before insert or update of company_id, role, active on public.profiles
for each row execute function public.enforce_free_operator_limit();

create or replace function public.enforce_free_monthly_load_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  month_start timestamptz;
  month_end timestamptz;
  monthly_loads integer;
begin
  if new.status::text = 'DUPLICATE_DELETED' or not public.is_free_plan_company(new.company_id) then
    return new;
  end if;

  month_start := date_trunc(
    'month',
    coalesce(new.captured_at, now()) at time zone 'America/Mexico_City'
  ) at time zone 'America/Mexico_City';
  month_end := month_start + interval '1 month';

  select count(*) into monthly_loads
  from public.fuel_loads
  where company_id = new.company_id
    and id is distinct from new.id
    and status::text <> 'DUPLICATE_DELETED'
    and captured_at >= month_start
    and captured_at < month_end;

  if monthly_loads >= 10 then
    raise exception 'El plan Free permite hasta 10 cargas por mes.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_free_monthly_load_limit on public.fuel_loads;
create trigger enforce_free_monthly_load_limit
before insert or update of company_id, captured_at, status on public.fuel_loads
for each row execute function public.enforce_free_monthly_load_limit();
