-- Permite conservar cargas duplicadas en el historial, sin incorporarlas a indicadores.
alter type public.fuel_load_status add value if not exists 'DUPLICATE_DELETED';

-- El administrador de la empresa puede corregir datos de perfiles de su propia empresa.
drop policy if exists "profiles company admin update" on public.profiles;
create policy "profiles company admin update"
on public.profiles
for update
using (
  public.current_role() in ('COMPANY_ADMIN', 'AFN_ADMIN')
  and (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN')
)
with check (
  public.current_role() in ('COMPANY_ADMIN', 'AFN_ADMIN')
  and (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN')
);

-- El administrador puede marcar una carga como eliminada por duplicidad.
drop policy if exists "loads company admin update" on public.fuel_loads;
create policy "loads company admin update"
on public.fuel_loads
for update
using (
  public.current_role() in ('COMPANY_ADMIN', 'AFN_ADMIN')
  and (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN')
)
with check (
  public.current_role() in ('COMPANY_ADMIN', 'AFN_ADMIN')
  and (company_id = public.current_company_id() or public.current_role() = 'AFN_ADMIN')
);
