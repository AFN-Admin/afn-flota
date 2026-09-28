-- Una carga con observación ya fue revisada por el administrador.
-- Solo una carga pendiente de validación puede corregirse o sustituir sus evidencias.

drop policy if exists "loads operator correct pending" on public.fuel_loads;
create policy "loads operator correct pending"
on public.fuel_loads
for update
using (
  registered_by = auth.uid()
  and status = 'PENDING_VALIDATION'
)
with check (
  registered_by = auth.uid()
  and company_id = public.current_company_id()
  and status = 'PENDING_VALIDATION'
);

drop policy if exists "evidences operator replace pending" on public.evidences;
create policy "evidences operator replace pending"
on public.evidences
for delete
using (
  exists (
    select 1
    from public.fuel_loads f
    where f.id = evidences.fuel_load_id
      and f.registered_by = auth.uid()
      and f.status = 'PENDING_VALIDATION'
  )
);

drop policy if exists "storage operator remove pending evidence" on storage.objects;
create policy "storage operator remove pending evidence"
on storage.objects
for delete
using (
  bucket_id = 'fuel-evidence'
  and exists (
    select 1
    from public.evidences e
    join public.fuel_loads f on f.id = e.fuel_load_id
    where e.storage_path = name
      and f.registered_by = auth.uid()
      and f.status = 'PENDING_VALIDATION'
  )
);
