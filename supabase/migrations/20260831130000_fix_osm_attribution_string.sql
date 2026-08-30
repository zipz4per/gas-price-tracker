-- Correct the ODbL attribution string.
--
-- The design and the PRD both record the required credit as "© OpenStreetMap
-- contributors" with a real copyright sign — "that exact string, which is the
-- form OSM's own copyright page gives" — and the function shipped an ASCII
-- "(c)" instead. The obligation is to reproduce the notice, not an
-- approximation of it, and the gap between what was documented and what was
-- returned is exactly the kind that survives review because both halves look
-- right on their own.
--
-- Function body otherwise unchanged.

create or replace function public.get_stations_with_reference_prices(
  p_locality  text,
  p_fuel_type text
)
returns setof public.station_reference_result
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_loc record;
begin
  -- Registered localities only, and an unregistered one is an error rather than
  -- an empty set. "We do not cover this town" and "we cover it and know of no
  -- stations" are different facts, and a caller that cannot tell them apart will
  -- report the wrong one to a driver.
  select l.display_name into v_loc
    from public.localities l
   where public.normalize_locality_label(l.display_name)
       = public.normalize_locality_label(p_locality);

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unrecognised locality: %L', p_locality),
      detail  = format('registered localities are %s',
                       (select string_agg(l.display_name, ', ' order by l.display_name)
                          from public.localities l)),
      hint    = 'A locality outside the registry is not covered by this app. '
                'Coverage is a data change, not a query change.';
  end if;

  -- One call, not one per station. It also validates p_fuel_type for us and
  -- raises 22023 on an unrecognised one, so this function inherits that
  -- behaviour instead of re-deriving it.
  return query
  with reference as (
    select * from public.get_doe_reference_prices(p_locality, p_fuel_type)
  ),
  priced as (
    -- Real brand rows only. The single has_data = false row carries no brand and
    -- would otherwise join to every station.
    select * from reference where has_data and brand is not null
  ),
  context as (
    -- Period and attribution survive even when there are no priced rows, so a
    -- station with no reference still reports which report was consulted.
    select doe_source_locality, proxy_source, fuel_type,
           period_start, period_end, period_label, source_url
      from reference limit 1
  )
  select
    s.id,
    s.provider_place_id,
    s.name,
    s.brand_code,
    b.display_name,
    s.address,
    s.latitude,
    s.longitude,
    l.display_name,

    (p.brand is not null),

    -- Names a person reads come from display_name and proxy_source, never from
    -- doe_source_locality. That column is the source document's own label, kept
    -- verbatim BECAUSE it contains errors: the NCR report spells Taguig City
    -- "Taguig Cty". It is the right value for matching and the wrong one to put
    -- in a sentence shown to a driver.
    case
      when p.brand is not null and c.proxy_source is not null then
        format('Locality-wide DOE range for %s across %s, used as a proxy for %s. '
               'Not a price observed at this station.',
               b.display_name, c.proxy_source, l.display_name)
      when p.brand is not null then
        format('Locality-wide DOE range for %s across %s. '
               'Not a price observed at this station.',
               b.display_name, l.display_name)
      when s.brand_code is null then
        'No reference price: this station''s brand is not yet identified.'
      else
        format('No reference price: DOE does not report %s for %s in %s.',
               b.display_name, c.fuel_type,
               coalesce(c.proxy_source, l.display_name))
    end,

    c.fuel_type,
    c.doe_source_locality,
    c.proxy_source,
    p.min_price, p.max_price, p.common_price,
    c.period_start, c.period_end, c.period_label, c.source_url,

    '© OpenStreetMap contributors'
  from public.stations s
  join public.localities l on l.id = s.locality_id
  left join public.brands b on b.code = s.brand_code
  cross join context c
  -- LEFT join: a station whose brand DOE does not price is returned WITHOUT a
  -- figure. Of 96 stations imported on 2026-08-31, DOE is silent on 35 and 5
  -- have no resolved brand at all; an inner join would delete 40 real places
  -- from the map.
  left join priced p on p.brand = s.brand_code
  where public.normalize_locality_label(l.display_name)
      = public.normalize_locality_label(p_locality)
  order by b.sort_order nulls last, s.name;
end;
$$;
