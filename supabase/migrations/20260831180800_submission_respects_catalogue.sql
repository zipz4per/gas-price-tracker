-- A station cannot be reported for a fuel its brand does not sell.
--
-- The catalogue is authoritative about a brand's range, and offering a grade a
-- station does not stock invites a price recorded against a product that does
-- not exist there - indistinguishable afterwards from a real observation, and
-- unfalsifiable, because nobody can go and check a pump that was never on the
-- forecourt.
--
-- The check applies only to a brand that HAS a catalogue. A brand with no
-- entries means "we have not established what it sells", not "it sells
-- nothing"; treating the two the same would, with the catalogue empty as it is
-- today, reject every report at every station.
--
-- The message names the BRAND. A driver told "RON 97 is not available" reads it
-- as a fault in the app; told "Petron does not sell RON 97", they know which
-- fact is being asserted and can tell us if it is wrong.

create or replace function public.submit_price_report(
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

  select s.id, s.latitude, s.longitude, s.name, s.brand_code
    into v_station
    from public.stations s
   where s.id = p_station_id;

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unregistered station: %L', p_station_id),
      hint    = 'Choose a station from stations_within_radius.';
  end if;

  -- The catalogue check, where there is a catalogue to check against.
  if v_station.brand_code is not null
     and exists (select 1 from public.brand_fuel_products p
                  where p.brand_code = v_station.brand_code)
     and not exists (select 1 from public.brand_fuel_products p
                      where p.brand_code = v_station.brand_code
                        and p.fuel_type_code = v_fuel_code) then
    raise exception using
      errcode = '22023',
      message = format('%s does not sell %s',
                       (select b.display_name from public.brands b
                         where b.code = v_station.brand_code),
                       (select ft.display_name from public.fuel_types ft
                         where ft.code = v_fuel_code)),
      detail  = format('%s sells %s',
                       (select b.display_name from public.brands b
                         where b.code = v_station.brand_code),
                       (select string_agg(p.product_name, ', ' order by p.sort_order)
                          from public.brand_fuel_products p
                         where p.brand_code = v_station.brand_code)),
      hint    = 'If this brand does sell it, the product catalogue is out of '
                'date rather than the report being wrong.';
  end if;

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
