-- The station read path: every station in a locality, each with the DOE figure
-- that applies to it.
--
-- The figure is a LOCALITY-WIDE BRAND RANGE, never a price observed at the
-- station. DOE's Caltex row for Taguig spans P84.90-P93.70 — an P8.80 spread no
-- single forecourt has in one monitoring period — so the row is already several
-- stations collapsed into one line. Attaching it to a pin without saying what it
-- is turns a true statement about a group into a false one about a member.
--
-- So reference_basis is NOT nullable and not optional. A consumer cannot obtain
-- the number without the sentence that says what the number is. This is the same
-- reasoning that put proxy attribution inside get_doe_reference_prices rather
-- than in its callers: a consumer who has to remember to add the caveat is a
-- consumer who will eventually forget.
--
-- Reference resolution is delegated to get_doe_reference_prices rather than
-- reimplemented. Proxy attribution, run gating, and absent-brand semantics are
-- three obligations that each fail silently, and having two functions that must
-- agree about them is how they start disagreeing.

create type public.station_reference_result as (
  -- The station.
  station_id          uuid,
  provider_place_id   text,
  station_name        text,
  brand_code          text,   -- null when our rules could not resolve one
  brand_display       text,
  address             text,
  latitude            numeric(9,6),
  longitude           numeric(9,6),
  locality            text,

  -- What the figure is. Always present, in every row, including the ones with
  -- no figure.
  has_reference_data  boolean,
  reference_basis     text,

  -- The figure, when there is one.
  fuel_type           text,
  doe_source_locality text,
  proxy_source        text,   -- null when sourced directly
  min_price           numeric(6,2),
  max_price           numeric(6,2),
  common_price        numeric(6,2),
  period_start        date,
  period_end          date,
  period_label        text,
  source_url          text,

  -- ODbL. Station data is extracted from OpenStreetMap and every surface that
  -- displays it must credit the source, so the credit travels with the data.
  station_attribution text
);

comment on type public.station_reference_result is
  'One row per station. reference_basis always says what min/max/common mean; '
  'has_reference_data = false means DOE does not price this brand and fuel type '
  'in this locality, which is a state the station is RETURNED in, never omitted.';

create function public.get_stations_with_reference_prices(
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

    '(c) OpenStreetMap contributors'
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

comment on function public.get_stations_with_reference_prices(text, text) is
  'Stations in a locality with the DOE brand range applicable to each. Returns '
  'every registered station, including those DOE does not price; raises 22023 '
  'for an unregistered locality or unrecognised fuel type. A registered locality '
  'with no stations returns an empty set.';

-- Postgres grants EXECUTE to PUBLIC on every new function by default, so a
-- grant to anon and authenticated adds nothing unless that default is revoked
-- first. Without the revoke, a SECURITY DEFINER function is callable by every
-- role that exists now or is created later, which is not what "readable without
-- authentication" was meant to say.
revoke all on function public.get_stations_with_reference_prices(text, text) from public;
grant execute on function public.get_stations_with_reference_prices(text, text)
  to anon, authenticated;

-- Same omission on the existing read path, which has carried the default PUBLIC
-- grant since it was created. Same fix.
revoke all on function public.get_doe_reference_prices(text, text) from public;
grant execute on function public.get_doe_reference_prices(text, text)
  to anon, authenticated;

-- resolve_station_brand is a pure helper over a public rules table; it reads
-- nothing sensitive and is not security definer, but it has no reason to be
-- callable by roles that were never considered either.
revoke all on function public.resolve_station_brand(text, text, text) from public;
grant execute on function public.resolve_station_brand(text, text, text)
  to anon, authenticated, service_role;
