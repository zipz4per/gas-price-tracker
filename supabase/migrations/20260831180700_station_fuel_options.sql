-- What to offer at a station, and in whose words.
--
-- Three cases, one call. A caller that has to remember the fallback is a caller
-- that will one day render an empty list on a screen serving a third of the
-- registry, so the fallback lives here - the same reasoning that put
-- reference_basis inside the read path rather than in its callers.
--
--   brand has a catalogue   the brand's products, in the brand's own order
--   brand has none          canonical grade names, every registered fuel type
--   station has no brand    the same
--
-- The last two are not degradations. The catalogue is empty today for every
-- brand, and 20 of 96 stations carry INDEPENDENT or no brand at all, so the
-- canonical path is the one the app actually runs on.
--
-- A brand with NO entries means "we have not established what it sells", which
-- is different from "it sells nothing". Only a brand that HAS a catalogue can
-- have a fuel type absent from it, and only then does absence mean anything.

create function public.get_station_fuel_options(p_station_id uuid)
returns table (
  fuel_type_code text,
  label          text,
  label_source   text,
  sort_order     integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_brand text;
  v_has_catalogue boolean;
begin
  select s.brand_code into v_brand
    from public.stations s
   where s.id = p_station_id;

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unregistered station: %L', p_station_id),
      hint    = 'Choose a station from stations_within_radius.';
  end if;

  v_has_catalogue := v_brand is not null and exists (
    select 1 from public.brand_fuel_products p where p.brand_code = v_brand);

  if v_has_catalogue then
    return query
      select p.fuel_type_code, p.product_name, 'brand'::text, p.sort_order
        from public.brand_fuel_products p
       where p.brand_code = v_brand
       order by p.sort_order;
  else
    return query
      -- fuel_types.sort_order is smallint; the catalogue's is integer.
      select ft.code, ft.display_name, 'canonical'::text, ft.sort_order::integer
        from public.fuel_types ft
       order by ft.sort_order;
  end if;
end;
$$;

comment on function public.get_station_fuel_options(uuid) is
  'The fuels to offer at a station, labelled as that station''s brand labels '
  'them. Falls back to canonical grade names when the brand has no catalogue or '
  'the station has no brand; never returns an empty list for a registered '
  'station.';

revoke all on function public.get_station_fuel_options(uuid) from public;
grant execute on function public.get_station_fuel_options(uuid) to anon, authenticated;
