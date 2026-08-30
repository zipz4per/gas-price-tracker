-- A station says why it has no figure, and the reason is the true one.
--
-- The sentence this function composes was the visible half of the defect. It
-- had exactly one way to explain an absent price:
--
--   'No reference price: DOE does not report %s for %s in %s.'
--
-- which is true only when the report covered this locality and fuel type and
-- carried no figure for this brand. With nothing ingested it was a confident
-- lie about DOE, and there was no error anywhere to notice it by.
--
-- The reason is composed HERE rather than returned raw for a client to phrase.
-- Four cases, one of which is an operational admission, and a client author
-- with no context deciding the wording is where the wrong sentence comes back.
-- The same argument put the brand-range label in this function rather than in
-- its callers.

alter type public.station_reference_result
  add attribute absence_reason public.reference_absence_reason cascade;

comment on type public.station_reference_result is
  'One row per station. reference_basis always says what min/max/common mean, '
  'or why they are absent; absence_reason carries the same decision as a value. '
  'has_reference_data = false is a state the station is RETURNED in, never '
  'omitted.';

create or replace function public.get_stations_with_reference_prices(p_locality text, p_fuel_type text)
 RETURNS SETOF station_reference_result
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    -- Reasons are checked from most general to most specific, because they
    -- nest: with nothing ingested, every locality is uncovered and every brand
    -- unreported. Reporting a more specific reason than the evidence supports
    -- is exactly the defect -- an empty database used to answer "DOE does not
    -- report Petron here", blaming the source for our own missing ingestion.
    case
      when p.brand is not null and c.proxy_source is not null then
        format('Locality-wide DOE range for %s across %s, used as a proxy for %s. '
               'Not a price observed at this station.',
               b.display_name, c.proxy_source, l.display_name)
      when p.brand is not null then
        format('Locality-wide DOE range for %s across %s. '
               'Not a price observed at this station.',
               b.display_name, l.display_name)

      -- Ours, not the source's. Says so plainly: this is the string most
      -- likely to prompt someone to go and load the data.
      when c.absence_reason = 'no_data_ingested' then
        'No reference price: no DOE reference data has been ingested yet.'
      when c.absence_reason = 'locality_not_covered' then
        format('No reference price: the ingested DOE data does not cover %s.',
               l.display_name)

      -- The source's, but about the fuel type rather than this brand.
      when c.absence_reason = 'fuel_type_not_reported' then
        format('No reference price: DOE did not report %s for %s.',
               c.fuel_type, coalesce(c.proxy_source, l.display_name))

      when s.brand_code is null then
        'No reference price: this station''s brand is not yet identified.'

      -- Only now is the original sentence true: the report covered this
      -- locality and fuel type and carried no figure for this brand.
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

    '© OpenStreetMap contributors',

    -- Last, because ALTER TYPE ... ADD ATTRIBUTE appends: absence_reason is
    -- attribute 23 of 23, and RETURN QUERY matches a composite by position.
    --
    -- The same decision as the sentence above, as a value, for a consumer that
    -- needs to branch rather than display. Null exactly when there is a figure.
    case
      when p.brand is not null          then null
      when c.absence_reason is not null then c.absence_reason
      when s.brand_code is null         then 'brand_not_identified'
      else                                   'brand_not_reported'
    end::public.reference_absence_reason
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
$function$

;
