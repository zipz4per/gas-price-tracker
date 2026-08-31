-- A station's reference figure becomes the locality-wide range across all
-- brands, not its own brand's range.
--
-- The brand range is narrower, which reads as a statement about the station
-- while remaining a statement about a group. Within one locality it resolves to
-- a single figure repeated across every station of that brand: on the Lipa City
-- map, RON 95 was 78.80 across 12 Petrons, 83.60 across 4 Caltexes and
-- 71.50-73.99 across 16 independents -- three numbers spread over 52 pins. A map
-- that appears to compare stations was comparing brands.
--
-- It is also missing exactly where a figure is most needed. DOE prices no range
-- at all for 17 of the 96 registered stations -- Phoenix, Seaoil, PTT, and the
-- five whose brand is unresolved -- while the locality-wide row covers every one
-- of them.
--
-- Two consequences worth stating.
--
-- Brand resolution leaves the pricing path. A station's brand no longer decides
-- whether it can show a figure, which is what makes it safe for
-- add-brand-fuel-products to correct brands in bulk.
--
-- Two absence reasons stop arising here. brand_not_reported and
-- brand_not_identified were about a brand, and the locality-wide range does not
-- consult one. They remain in the enum and remain correct wherever a brand is
-- genuinely the subject; they are simply not reachable from this function any
-- more.

create or replace function public.get_stations_with_reference_prices(
  p_locality  text,
  p_fuel_type text
)
returns setof public.station_reference_result
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
  overall as (
    -- The locality-wide row: every outlet of every brand the source surveyed,
    -- collapsed into one range. At most one row, so it attaches to every station
    -- without a join key.
    select * from reference where has_data and brand = 'OVERALL'
  ),
  context as (
    -- Period and attribution survive even when there is no figure, so a station
    -- with no reference still reports which report was consulted.
    select doe_source_locality, proxy_source, fuel_type, absence_reason,
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
    --
    -- Reasons are checked from most general to most specific, because they
    -- nest: with nothing ingested, every locality is uncovered and every fuel
    -- type unreported. Reporting a more specific reason than the evidence
    -- supports is exactly the defect this ordering exists to prevent.
    case
      when p.brand is not null and c.proxy_source is not null then
        format('Locality-wide DOE range across all brands in %s, used as a proxy '
               'for %s. Not a price observed at this station.',
               c.proxy_source, l.display_name)
      when p.brand is not null then
        format('Locality-wide DOE range across all brands in %s. '
               'Not a price observed at this station.',
               l.display_name)

      -- Ours, not the source's. Says so plainly: this is the string most
      -- likely to prompt someone to go and load the data.
      when c.absence_reason = 'no_data_ingested' then
        'No reference price: no DOE reference data has been ingested yet.'
      when c.absence_reason = 'locality_not_covered' then
        format('No reference price: the ingested DOE data does not cover %s.',
               l.display_name)

      -- The source's, and now about the fuel type only. A brand can no longer
      -- be the reason, because the figure no longer consults one.
      else
        format('No reference price: DOE did not report %s for %s.',
               c.fuel_type, coalesce(c.proxy_source, l.display_name))
    end,

    c.fuel_type,
    c.doe_source_locality,
    c.proxy_source,
    p.min_price, p.max_price, p.common_price,
    c.period_start, c.period_end, c.period_label, c.source_url,

    '© OpenStreetMap contributors',

    -- Last, because ALTER TYPE ... ADD ATTRIBUTE appends: absence_reason is
    -- attribute 23 of 23, and RETURN QUERY matches a composite by position.
    --
    -- The brand-shaped reasons are gone. What remains is the reason carried up
    -- from the reference resolver, and -- for the case where figures exist but
    -- no locality-wide row does -- the fuel type. That last branch is
    -- unreachable against the data as loaded, where every locality and fuel
    -- type with any figure also carries an OVERALL row.
    case
      when p.brand is not null          then null
      when c.absence_reason is not null then c.absence_reason
      else                                   'fuel_type_not_reported'
    end::public.reference_absence_reason
  from public.stations s
  join public.localities l on l.id = s.locality_id
  left join public.brands b on b.code = s.brand_code
  cross join context c
  -- LEFT join on a single row: every station in the locality gets the same
  -- range, and a locality with no figure for this fuel type still returns every
  -- station without one. An inner join would delete real places from the map.
  left join overall p on true
  where public.normalize_locality_label(l.display_name)
      = public.normalize_locality_label(p_locality)
  order by b.sort_order nulls last, s.name;
end;
$function$;
