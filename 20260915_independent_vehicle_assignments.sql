-- Asignación independiente de operadores, con máximo de tres activos por unidad.
create or replace function public.enforce_vehicle_assignment_limit()
returns trigger language plpgsql as $$
begin
  if new.active and not exists (
    select 1 from public.vehicle_assignments
    where id = new.id and active
  ) and (select count(*) from public.vehicle_assignments where vehicle_id = new.vehicle_id and active) >= 3 then
    raise exception 'Una unidad no puede tener más de 3 operadores activos asignados.';
  end if;
  return new;
end;
$$;

drop trigger if exists vehicle_assignment_limit on public.vehicle_assignments;
create trigger vehicle_assignment_limit
before insert or update of vehicle_id, active on public.vehicle_assignments
for each row execute function public.enforce_vehicle_assignment_limit();

drop policy if exists "assignments company read" on public.vehicle_assignments;
drop policy if exists "assignments company admin write" on public.vehicle_assignments;
create policy "assignments company read" on public.vehicle_assignments for select using (
  operator_id = auth.uid() or public.current_role() = 'AFN_ADMIN' or exists (
    select 1 from public.vehicles v
    where v.id = vehicle_id and v.company_id = public.current_company_id()
  )
);
create policy "assignments company admin write" on public.vehicle_assignments for all using (
  public.current_role() in ('COMPANY_ADMIN','AFN_ADMIN') and (
    public.current_role() = 'AFN_ADMIN' or exists (
      select 1 from public.vehicles v where v.id = vehicle_id and v.company_id = public.current_company_id()
    )
  )
) with check (
  public.current_role() in ('COMPANY_ADMIN','AFN_ADMIN') and (
    public.current_role() = 'AFN_ADMIN' or exists (
      select 1 from public.vehicles v where v.id = vehicle_id and v.company_id = public.current_company_id()
    )
  )
);
