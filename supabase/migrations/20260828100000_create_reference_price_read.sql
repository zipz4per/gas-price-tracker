-- The reference-price read path.
--
-- Three obligations converge here, and every one of them fails SILENTLY when
-- done wrong, which is why they live in one function rather than in each
-- caller:
--
--   1. Proxy resolution. Malvar has no DOE data of its own; it borrows
--      Tanauan City's. A consumer that shows those figures without saying so
--      tells a driver they are looking at official prices for their own town.
--   2. Run visibility. Only rows under a 'succeeded' run are real. A caller
--      querying tables directly can read a half-written or failed run.
--   3. Absent-brand semantics. A brand with no published price has no row;
--      inventing a zero would be a lie about the price of fuel.
--
-- None of those mistakes raises an error. They produce plausible wrong answers,
-- so the only reliable defence is making the wrong query impossible to express.

-- Result shape. Attribution is ALWAYS present — empty for direct localities,
-- the substitute's name for proxied ones — because an optional field is one a
-- caller can forget to select.
create type public.doe_price_result as (
  locality            text,   -- as requested, e.g. 'Malvar'
  doe_source_locality text,   -- where the figures actually came from
  proxy_source        text,   -- attribution; NULL when sourced directly
  fuel_type           text,
  brand               text,
  brand_presence      public.doe_brand_presence,
  min_price           numeric(6,2),
  max_price           numeric(6,2),
  common_price        numeric(6,2),
  period_start        date,
  period_end          date,
  period_label        text,   -- verbatim: DOE does not always report a week
  recorded_at         timestamptz,
  source_url          text,
  has_data            boolean -- false on the single no-data row
);

comment on type public.doe_price_result is
  'One row per brand, plus the OVERALL range. A single row with has_data = false '
  'means the locality is registered but has no reference data for that fuel type.';

create or replace function public.get_doe_reference_prices(
  p_locality  text,
  p_fuel_type text
)
returns setof public.doe_price_result
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_loc     record;
  v_report  record;
begin
  -- Registered localities only. An unregistered locality is not covered, which
  -- is a different fact from having no data, so it returns nothing at all.
  select l.display_name, l.doe_source_label, l.sourcing_mode, l.proxy_source_display_name
    into v_loc
  from public.localities l
  where public.normalize_locality_label(l.display_name)
      = public.normalize_locality_label(p_locality);

  if not found then
    return;
  end if;

  -- The latest SUCCEEDED run carrying this locality. Ordering by period_end
  -- rather than by recorded_at means a late re-load of an older period cannot
  -- displace newer figures.
  select lr.id, lr.status as locality_status,
         r.period_start, r.period_end, r.period_label, r.recorded_at, r.source_url
    into v_report
  from public.doe_locality_reports lr
  join public.doe_load_runs r on r.id = lr.run_id
  where r.status = 'succeeded'
    and public.normalize_locality_label(lr.doe_source_label)
      = public.normalize_locality_label(v_loc.doe_source_label)
  order by r.period_end desc, r.recorded_at desc
  limit 1;

  -- No run at all for this locality: an explicit no-data row, not an error and
  -- not an empty set. The app must render "no reports yet", never a blank
  -- screen (PRD FR-3), and that is the normal state before the first load.
  if not found then
    return query select
      v_loc.display_name, v_loc.doe_source_label, v_loc.proxy_source_display_name,
      p_fuel_type, null::text, null::public.doe_brand_presence,
      null::numeric(6,2), null::numeric(6,2), null::numeric(6,2),
      null::date, null::date, null::text, null::timestamptz, null::text,
      false;
    return;
  end if;

  -- Data exists for the locality but not for this fuel type. Same explicit
  -- no-data row: figures are never borrowed across fuel types, so a locality
  -- with Diesel but no Kerosene reports no Kerosene rather than Diesel's price.
  if not exists (
    select 1 from public.doe_reference_prices p
    where p.locality_report_id = v_report.id
      and p.fuel_type_code = p_fuel_type
  ) then
    return query select
      v_loc.display_name, v_loc.doe_source_label, v_loc.proxy_source_display_name,
      p_fuel_type, null::text, null::public.doe_brand_presence,
      null::numeric(6,2), null::numeric(6,2), null::numeric(6,2),
      v_report.period_start, v_report.period_end, v_report.period_label,
      v_report.recorded_at, v_report.source_url,
      false;
    return;
  end if;

  -- Real data. A brand with no published figure simply has no row here, which
  -- is what a blank source column means. Brands marked no_outlet DO appear —
  -- "this brand has no station in this town" is useful, and distinct from
  -- "this brand's price was unavailable".
  return query
    select
      v_loc.display_name,
      v_loc.doe_source_label,
      v_loc.proxy_source_display_name,
      p.fuel_type_code,
      p.brand_code,
      p.brand_presence,
      p.min_price, p.max_price, p.common_price,
      v_report.period_start, v_report.period_end, v_report.period_label,
      v_report.recorded_at, v_report.source_url,
      true
    from public.doe_reference_prices p
    join public.brands b on b.code = p.brand_code
    where p.locality_report_id = v_report.id
      and p.fuel_type_code = p_fuel_type
    order by b.sort_order, p.brand_code;
end;
$$;

comment on function public.get_doe_reference_prices(text, text) is
  'Reference prices for a locality and fuel type. Resolves proxy sourcing, '
  'restricts to the latest succeeded run, and returns an explicit has_data = '
  'false row when there is nothing to show. Stale data is served with its '
  'period rather than withheld.';

-- Readable without authentication: this is public reference data and the app
-- has no accounts. The function is stable and read-only; there is no write
-- path through it.
grant execute on function public.get_doe_reference_prices(text, text)
  to anon, authenticated;
