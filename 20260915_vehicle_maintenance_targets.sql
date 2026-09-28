-- Metas de mantenimiento configuradas por el administrador de cada empresa.
alter table public.vehicles
  add column if not exists next_maintenance_odometer_km integer,
  add column if not exists next_maintenance_hourmeter_hours numeric(12,2);

alter table public.vehicles
  drop constraint if exists vehicles_next_maintenance_odometer_check,
  drop constraint if exists vehicles_next_maintenance_hourmeter_check;

alter table public.vehicles
  add constraint vehicles_next_maintenance_odometer_check
    check (next_maintenance_odometer_km is null or next_maintenance_odometer_km > 0),
  add constraint vehicles_next_maintenance_hourmeter_check
    check (next_maintenance_hourmeter_hours is null or next_maintenance_hourmeter_hours > 0);
