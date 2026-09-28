-- Consulta controlada de evidencias para la empresa propietaria de cada carga.
drop policy if exists "evidences company read" on public.evidences;
create policy "evidences company read"
on public.evidences
for select
using (
  exists (
    select 1
    from public.fuel_loads f
    where f.id = evidences.fuel_load_id
      and (
        f.company_id = public.current_company_id()
        or public.current_role() = 'AFN_ADMIN'
      )
  )
);

-- Permite abrir o descargar solo los archivos ligados a cargas de la propia empresa.
drop policy if exists "storage evidence company read" on storage.objects;
create policy "storage evidence company read"
on storage.objects
for select
using (
  bucket_id = 'fuel-evidence'
  and exists (
    select 1
    from public.evidences e
    join public.fuel_loads f on f.id = e.fuel_load_id
    where e.storage_path = name
      and (
        f.company_id = public.current_company_id()
        or public.current_role() = 'AFN_ADMIN'
      )
  )
);
