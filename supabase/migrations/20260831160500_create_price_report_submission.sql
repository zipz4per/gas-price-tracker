-- Submitting a price, and finding the stations you could be standing at.
--
-- The whole submission path is one SECURITY DEFINER function because that is
-- what makes its checks unavoidable. The tables grant anon nothing but SELECT
-- and carry no write policy, so there is no route that reaches price_reports
-- without passing through here.
--
-- PRIVACY. The submitter's coordinates are arguments. They are compared against
-- a station's position, they decide a boolean, and they are never written
-- anywhere. price_reports has no column that could hold them. What survives the
-- call is the station, the price, the time, and the verdict.

-- One definition of distance, used by both functions below.
--
-- Equirectangular rather than PostGIS or haversine. At the scale that matters
-- here - a few hundred metres, at 14 degrees north - the approximation error is
-- centimetres, and 96 station rows do not need a spatial index. Two copies of
-- this formula would be two things that can drift; there is one.
create function public.distance_metres(
  p_lat_a numeric, p_lon_a numeric,
  p_lat_b numeric, p_lon_b numeric
)
returns numeric
language sql
immutable
parallel safe
set search_path = ''
as $$
  select 111320 * sqrt(
           power(p_lat_a - p_lat_b, 2)
         + power((p_lon_a - p_lon_b) * cos(radians(p_lat_a)), 2)
         );
$$;

comment on function public.distance_metres(numeric, numeric, numeric, numeric) is
  'Great-circle distance in metres, equirectangular approximation. Accurate to '
  'centimetres over the few hundred metres the proximity check cares about.';

-- The stations a submitter could be at.
--
-- Proximity AUTHORIZES a report and cannot IDENTIFY the station. The provider's
-- own data puts competing brands 27-40 m apart - a Petron and a Shell 31 m
-- apart, a Petro Gazz and a Foxx 27 m apart - and gives 22 of 96 stations a
-- neighbour inside 100 m, while phone GPS is 5-20 m in the open and worse among
-- tall buildings. No radius both admits an ordinary positioning error and
-- resolves which forecourt someone is on.
--
-- So this returns every candidate, ordered by distance, and the submitter picks.
-- It returns them even when there is only one, because a caller that sometimes
-- auto-selects is a caller that will auto-select the wrong one.
create function public.stations_within_radius(
  p_latitude  numeric,
  p_longitude numeric
)
returns table (
  station_id      uuid,
  provider_place_id text,
  station_name    text,
  brand_display   text,
  address         text,
  latitude        numeric(9,6),
  longitude       numeric(9,6),
  locality        text,
  distance_metres numeric
)
language sql
stable
set search_path = ''
as $$
  select s.id, s.provider_place_id, s.name, b.display_name, s.address,
         s.latitude, s.longitude, l.display_name,
         round(public.distance_metres(p_latitude, p_longitude, s.latitude, s.longitude), 1)
    from public.stations s
    join public.localities l on l.id = s.locality_id
    left join public.brands b on b.code = s.brand_code
   where p_latitude is not null
     and p_longitude is not null
     and public.distance_metres(p_latitude, p_longitude, s.latitude, s.longitude)
       <= (select ps.proximity_radius_metres from public.price_report_settings ps)
   order by 9;
$$;

comment on function public.stations_within_radius(numeric, numeric) is
  'Registered stations within the configured proximity radius, nearest first. '
  'The submitter chooses among these; the system never chooses for them.';

-- Submit a price observed at a station.
create function public.submit_price_report(
  p_station_id uuid,
  p_fuel_type  text,
  p_price      numeric,
  p_latitude   numeric,
  p_longitude  numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fuel_code text;
  v_station   record;
  v_settings  record;
  v_distance  numeric;
  v_recent    integer;
  v_report_id uuid;
begin
  select * into v_settings from public.price_report_settings limit 1;

  -- Fuel type, matched the way every other read path matches one: normalized,
  -- and deliberately not fuzzy, so an unrecognised value is unrecognised rather
  -- than rounded to its nearest neighbour.
  select ft.code into v_fuel_code
    from public.fuel_types ft
   where public.normalize_locality_label(ft.code)
       = public.normalize_locality_label(p_fuel_type);

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unrecognised fuel type: %L', p_fuel_type),
      detail  = format('registered fuel types are %s',
                       (select string_agg(ft.code, ', ' order by ft.code)
                          from public.fuel_types ft));
  end if;

  select s.id, s.latitude, s.longitude, s.name
    into v_station
    from public.stations s
   where s.id = p_station_id;

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unregistered station: %L', p_station_id),
      hint    = 'Choose a station from stations_within_radius.';
  end if;

  -- No location, no report.
  --
  -- Rejected rather than stored with the verdict false. An unverified report
  -- would be indistinguishable afterwards from a verified one everywhere except
  -- in one boolean, and the first consumer to forget that boolean would present
  -- an unchecked price as a checked one.
  if p_latitude is null or p_longitude is null then
    raise exception using
      errcode = '22023',
      message = 'a price report requires the submitter''s location',
      hint    = 'Location could not be determined, was not available in time, '
                'or was declined. A report is not accepted without it.';
  end if;

  v_distance := public.distance_metres(p_latitude, p_longitude,
                                       v_station.latitude, v_station.longitude);

  if v_distance > v_settings.proximity_radius_metres then
    raise exception using
      errcode = '22023',
      message = format('not at %s: %s m away, limit is %s m',
                       v_station.name, round(v_distance), v_settings.proximity_radius_metres),
      hint    = 'A price is reported from the forecourt it was read at.';
  end if;

  -- Plausibility, from the bounds registered against the fuel type.
  --
  -- These are the primary test rather than the DOE range, which covers 8 of 21
  -- locality and fuel-type combinations and is absent for three fuel types
  -- entirely - a check that depended on it would not run for most reports.
  if exists (
    select 1 from public.fuel_types ft
     where ft.code = v_fuel_code
       and (p_price < ft.min_plausible or p_price > ft.max_plausible)
  ) then
    raise exception using
      errcode = '22023',
      message = format('implausible price for %s: %s', v_fuel_code, p_price),
      detail  = format('plausible range is %s to %s',
                       (select ft.min_plausible from public.fuel_types ft where ft.code = v_fuel_code),
                       (select ft.max_plausible from public.fuel_types ft where ft.code = v_fuel_code));
  end if;

  -- Rate cap.
  --
  -- Without accounts there is no per-person limit, so this bounds how fast
  -- anyone can churn one station's displayed value. It does not stop a
  -- determined submitter standing at the pump; reports are retained and the
  -- newest wins, so the next honest report corrects it.
  select count(*) into v_recent
    from public.price_reports r
   where r.station_id = p_station_id
     and r.fuel_type_code = v_fuel_code
     and r.observed_at > now() - interval '1 hour';

  if v_recent >= v_settings.station_fuel_reports_per_hour then
    raise exception using
      errcode = '22023',
      message = format('%s has been reported too often for %s in the past hour',
                       v_station.name, v_fuel_code),
      detail  = format('limit is %s per hour', v_settings.station_fuel_reports_per_hour);
  end if;

  insert into public.price_reports (station_id, fuel_type_code, price, proximity_verified)
  values (p_station_id, v_fuel_code, p_price, true)
  returning id into v_report_id;

  return v_report_id;
end;
$$;

comment on function public.submit_price_report(uuid, text, numeric, numeric, numeric) is
  'The only way a price report is written. Checks the fuel type, the station, '
  'the submitter''s proximity, the price''s plausibility, and the per-station '
  'rate cap. The submitter''s coordinates are arguments only and are never '
  'stored.';

-- Postgres grants EXECUTE to PUBLIC on every new function by default, so a
-- grant to anon and authenticated adds nothing unless that default is revoked
-- first.
revoke all on function public.distance_metres(numeric, numeric, numeric, numeric) from public;
revoke all on function public.stations_within_radius(numeric, numeric) from public;
revoke all on function public.submit_price_report(uuid, text, numeric, numeric, numeric) from public;

grant execute on function public.distance_metres(numeric, numeric, numeric, numeric)
  to anon, authenticated, service_role;
grant execute on function public.stations_within_radius(numeric, numeric)
  to anon, authenticated;
grant execute on function public.submit_price_report(uuid, text, numeric, numeric, numeric)
  to anon, authenticated;
