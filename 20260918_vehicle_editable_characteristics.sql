-- Datos editables del activo. No modifica ninguna carga ni evidencia histórica.
alter table public.vehicles
  add column if not exists make text,
  add column if not exists model text,
  add column if not exists model_year integer,
  add column if not exists initial_odometer_km integer,
  add column if not exists initial_hourmeter_hours numeric(12,2);

alter table public.vehicles
  drop constraint if exists vehicles_model_year_check,
  drop constraint if exists vehicles_initial_odometer_check,
  drop constraint if exists vehicles_initial_hourmeter_check;

alter table public.vehicles
  add constraint vehicles_model_year_check check (model_year is null or model_year between 1900 and 2100),
  add constraint vehicles_initial_odometer_check check (initial_odometer_km is null or initial_odometer_km >= 0),
  add constraint vehicles_initial_hourmeter_check check (initial_hourmeter_hours is null or initial_hourmeter_hours >= 0);
