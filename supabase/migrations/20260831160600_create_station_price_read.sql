-- What a station charges, and what kind of answer that is.
--
-- Three rungs, in order of what they claim:
--
--   observed    someone reported this price at this station
--   derived     an earlier report here, carried across announced adjustments
--   reference   the DOE locality-wide range; nobody has reported here
--
-- A station is returned in every case, including when no rung yields a figure.
-- Absence is a state the row is RETURNED in, never a row that is missing.
--
-- Derived prices are computed here rather than written by a scheduled job. A
-- job would have to run exactly once per adjustment, be safely re-runnable, and
-- would leave every row wrong until it ran. Computing means a late-published
-- adjustment, a corrected amount, or a backfill all take effect immediately and
-- retroactively, and the count of adjustments applied falls out of the same
-- query instead of being tracked in a column that can disagree with the rows it
-- summarises.
--
-- The reference rung delegates to get_doe_reference_prices rather than reading
-- doe_reference_prices directly. Proxy attribution, run gating and absence
-- semantics are three obligations that each fail silently, and two functions
-- that must agree about them are two functions that will eventually disagree.

create function public.get_station_prices(
  p_locality  text,
  p_fuel_type text default null
)
returns setof public.station_price_result
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_loc      record;
  v_settings record;
begin
  select * into v_settings from public.price_report_settings limit 1;

  -- A locality outside the registry is an error, not an empty set. "We do not
  -- cover this town" and "we cover it and know of no stations" are different
  -- facts, and a caller that cannot tell them apart reports the wrong one.
  select l.id, l.display_name into v_loc
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
      hint    = 'A locality outside the registry is not covered by this app.';
  end if;

  -- A fuel type is optional. Omitting it returns every registered fuel type,
  -- which is what a station card showing several grades needs; naming an
  -- unrecognised one is still an error rather than an empty result.
  if p_fuel_type is not null and not exists (
       select 1 from public.fuel_types ft
        where public.normalize_locality_label(ft.code)
            = public.normalize_locality_label(p_fuel_type)
     ) then
    raise exception using
      errcode = '22023',
      message = format('unrecognised fuel type: %L', p_fuel_type),
      detail  = format('registered fuel types are %s',
                       (select string_agg(ft.code, ', ' order by ft.code)
                          from public.fuel_types ft));
  end if;

  return query
  with fuels as (
    select ft.code, ft.display_name, ft.sort_order
      from public.fuel_types ft
     where p_fuel_type is null
        or public.normalize_locality_label(ft.code)
         = public.normalize_locality_label(p_fuel_type)
  ),
  sta as (
    select s.id, s.provider_place_id, s.name, s.brand_code, s.address,
           s.latitude, s.longitude,
           l.display_name as locality_name,
           b.display_name as brand_display,
           b.sort_order   as brand_sort
      from public.stations s
      join public.localities l on l.id = s.locality_id
      left join public.brands b on b.code = s.brand_code
     where l.id = v_loc.id
  ),
  -- One reference row per fuel type: the locality-wide OVERALL figure, or the
  -- single no-data row that carries the reason there is none.
  --
  -- The third branch - reference data exists for this fuel but carries no
  -- OVERALL row - is unreachable against the data as loaded, where every
  -- locality and fuel type with any figure also has an OVERALL one. It is
  -- handled rather than assumed away: since the reference figure IS the
  -- locality-wide one, a source publishing no locality-wide figure for a fuel
  -- type there is not reporting that fuel type for this purpose.
  ref as (
    select f.code as fuel_code,
           max(r.doe_source_locality) filter (where true) as doe_source_locality,
           max(r.proxy_source)        filter (where true) as proxy_source,
           max(r.period_start)        filter (where true) as period_start,
           max(r.period_end)          filter (where true) as period_end,
           max(r.period_label)        filter (where true) as period_label,
           max(r.source_url)          filter (where true) as source_url,
           bool_or(r.brand = 'OVERALL' and r.has_data)     as has_overall,
           max(r.min_price)    filter (where r.brand = 'OVERALL') as min_price,
           max(r.max_price)    filter (where r.brand = 'OVERALL') as max_price,
           max(r.common_price) filter (where r.brand = 'OVERALL') as common_price,
           min(r.absence_reason) filter (where not r.has_data)    as absence_reason
      from fuels f
      cross join lateral public.get_doe_reference_prices(v_loc.display_name, f.code) r
     group by f.code
  ),
  -- The newest report per station and fuel type.
  newest as (
    select distinct on (pr.station_id, pr.fuel_type_code)
           pr.station_id, pr.fuel_type_code, pr.price, pr.observed_at
      from public.price_reports pr
     order by pr.station_id, pr.fuel_type_code, pr.observed_at desc
  ),
  tally as (
    select pr.station_id, pr.fuel_type_code, count(*)::integer as report_count
      from public.price_reports pr
     group by 1, 2
  ),
  -- Adjustments effective since each observation. This is the derived rung.
  since_obs as (
    select n.station_id, n.fuel_type_code,
           coalesce(sum(a.amount), 0)::numeric(6,2) as total,
           count(a.*)::integer                      as applied
      from newest n
      left join public.price_adjustments a
        on a.fuel_type_code = n.fuel_type_code
       and a.effective_at   >  n.observed_at
       and a.effective_at   <= now()
     group by 1, 2
  ),
  -- Adjustments effective since the reference period closed, so a station with
  -- no observation does not fall further behind at each cycle while reported
  -- stations stay current.
  since_ref as (
    select rf.fuel_code,
           coalesce(sum(a.amount), 0)::numeric(6,2) as total,
           count(a.*)::integer                      as applied
      from ref rf
      left join public.price_adjustments a
        on a.fuel_type_code = rf.fuel_code
       and rf.period_end is not null
       and a.effective_at   >  ((rf.period_end + 1)::timestamp at time zone 'Asia/Manila')
       and a.effective_at   <= now()
     group by 1
  ),
  grid as (
    select st.*, f.code as fuel_code, f.display_name as fuel_display, f.sort_order as fuel_sort,
           n.price       as baseline_price,
           n.observed_at as baseline_observed_at,
           t.report_count,
           so.total   as obs_shift,
           so.applied as obs_applied,
           rf.has_overall, rf.min_price, rf.max_price, rf.common_price,
           rf.absence_reason, rf.doe_source_locality, rf.proxy_source,
           rf.period_start, rf.period_end, rf.period_label, rf.source_url,
           sr.total   as ref_shift,
           sr.applied as ref_applied,
           -- Is the observation still close enough to an observation to show?
           --
           -- Two conditions, and the day limit is not redundant with the count.
           -- The count only advances while adjustments are being ingested; if
           -- the feed stops, it stays at zero and a months-old observation
           -- would keep presenting itself as freshly observed.
           (n.observed_at is not null
             and so.applied <= v_settings.carry_forward_max_adjustments
             and n.observed_at > now() - make_interval(days => v_settings.carry_forward_max_days)
           ) as carry_ok
      from sta st
      cross join fuels f
      left join newest    n  on n.station_id = st.id and n.fuel_type_code = f.code
      left join tally     t  on t.station_id = st.id and t.fuel_type_code = f.code
      left join since_obs so on so.station_id = st.id and so.fuel_type_code = f.code
      left join ref       rf on rf.fuel_code = f.code
      left join since_ref sr on sr.fuel_code = f.code
  )
  select
    g.id, g.provider_place_id, g.name, g.brand_code, g.brand_display, g.address,
    g.latitude, g.longitude, g.locality_name,
    g.fuel_code, g.fuel_display,

    -- Which rung.
    case
      when g.carry_ok and g.obs_applied = 0 then 'observed'::public.price_kind
      when g.carry_ok                       then 'derived'::public.price_kind
      when g.has_overall                    then 'reference'::public.price_kind
      else null
    end,

    -- The sentence. Present in every row, including rows with no figure.
    (case
      when g.carry_ok and g.obs_applied = 0 then
        format('Reported at this station on %s. %s report(s) on record.',
               to_char(g.baseline_observed_at at time zone 'Asia/Manila', 'DD Mon YYYY'),
               g.report_count)
      when g.carry_ok then
        format('Estimated from a report of %s at this station on %s, adjusted by %s '
               'across %s announced price change(s). Not observed since.',
               g.baseline_price,
               to_char(g.baseline_observed_at at time zone 'Asia/Manila', 'DD Mon YYYY'),
               (case when g.obs_shift >= 0 then '+' else '' end || g.obs_shift::text),
               g.obs_applied)
      when g.has_overall and g.proxy_source is not null then
        format('Locality-wide DOE range across all brands in %s, used as a proxy for %s%s. '
               'Not a price observed at this station.',
               g.proxy_source, g.locality_name,
               case when g.ref_applied > 0
                    then format(', adjusted by %s across %s announced price change(s)',
                                (case when g.ref_shift >= 0 then '+' else '' end || g.ref_shift::text), g.ref_applied)
                    else '' end)
      when g.has_overall then
        format('Locality-wide DOE range across all brands in %s%s. '
               'Not a price observed at this station.',
               g.locality_name,
               case when g.ref_applied > 0
                    then format(', adjusted by %s across %s announced price change(s)',
                                (case when g.ref_shift >= 0 then '+' else '' end || g.ref_shift::text), g.ref_applied)
                    else '' end)
      when g.absence_reason = 'no_data_ingested' then
        'No price: nobody has reported here and no reference data has been ingested.'
      when g.absence_reason = 'locality_not_covered' then
        format('No price: nobody has reported here and the ingested reference data '
               'does not cover %s.', g.locality_name)
      else
        format('No price: nobody has reported here and DOE does not report %s in %s.',
               g.fuel_display, coalesce(g.proxy_source, g.locality_name))
    end)::public.price_basis,

    -- The reason, when there is no figure at all.
    case
      when g.carry_ok or g.has_overall then null
      else coalesce(g.absence_reason, 'fuel_type_not_reported'::public.reference_absence_reason)
    end,

    -- The figure, when it is a single price.
    (case when g.carry_ok then g.baseline_price + g.obs_shift else null end)::numeric(6,2),

    case when g.carry_ok then g.report_count else null end,
    case when g.carry_ok then g.baseline_observed_at else null end,
    (case when g.carry_ok and g.obs_applied > 0 then g.baseline_price else null end)::numeric(6,2),
    case when g.carry_ok and g.obs_applied > 0 then g.baseline_observed_at else null end,
    case when g.carry_ok then g.obs_applied else null end,

    -- The figure, when it is a range.
    (case when not g.carry_ok and g.has_overall then g.min_price + g.ref_shift else null end)::numeric(6,2),
    (case when not g.carry_ok and g.has_overall then g.max_price + g.ref_shift else null end)::numeric(6,2),
    (case when not g.carry_ok and g.has_overall then g.common_price + g.ref_shift else null end)::numeric(6,2),
    (case when not g.carry_ok and g.has_overall and g.ref_applied > 0 then g.ref_shift else null end)::numeric(6,2),

    g.doe_source_locality, g.proxy_source,
    g.period_start, g.period_end, g.period_label, g.source_url,

    '© OpenStreetMap contributors'
  from grid g
  order by g.brand_sort nulls last, g.name, g.fuel_sort;
end;
$$;

comment on function public.get_station_prices(text, text) is
  'Every station in a locality with its current price and what kind of price it '
  'is: observed at the station, derived from an earlier observation across '
  'announced adjustments, or the DOE locality-wide reference. Omit the fuel '
  'type for every registered fuel; an unregistered locality or unrecognised '
  'fuel type raises 22023.';

revoke all on function public.get_station_prices(text, text) from public;
grant execute on function public.get_station_prices(text, text) to anon, authenticated;
