-- The DOE reference price loader.
--
-- CONTRACT: the caller supplies flat rows — one per locality × fuel type ×
-- brand — as a JSON array:
--
--   [{"locality":"Tanauan City","fuel":"RON_91","brand":"PETRON",
--     "min":"74.50","max":"74.50","common":"None"}, ...]
--
-- Prices are raw TEXT, exactly as the document prints them, so absence markers
-- normalize in one place. This flat shape is also the seam the future automated
-- parser targets: its job becomes "produce these rows", not "understand the
-- storage model", which keeps the highest-risk component as small as possible
-- and leaves the manual path available as a fallback when it breaks.
--
-- ATOMICITY: the run row is inserted before the work block, so a failure rolls
-- the work back to the block's implicit savepoint while the run survives and is
-- marked 'failed' with a reason. Readers only see 'succeeded' runs, so a failed
-- load is retained for operator review yet invisible to consumers — and the
-- previous period's data is untouched, because nothing is ever overwritten.

create or replace function public.load_doe_reference_prices(
  p_region_code   text,
  p_source_url    text,
  p_period_start  date,
  p_period_end    date,
  p_period_label  text,
  p_rows          jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id      uuid;
  v_row         jsonb;
  v_locality    text;
  v_report_id   uuid;
  v_min         numeric;
  v_max         numeric;
  v_common      numeric;
  v_lo          numeric;
  v_hi          numeric;
  v_expected    record;
  v_match_count int;
  v_price_rows  int;
begin
  insert into public.doe_load_runs
    (doe_region_code, status, source_url, period_start, period_end, period_label)
  values
    (p_region_code, 'in_progress', p_source_url, p_period_start, p_period_end, p_period_label)
  returning id into v_run_id;

  begin
    if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
      raise exception 'no input rows supplied';
    end if;

    -- ---- 1. Locality reports -------------------------------------------
    -- A locality where ANY cell carries "No LFRO" has no retail outlet at all.
    -- That is a valid published state, not missing data, and carries no prices.
    for v_locality in
      select distinct r->>'locality' from jsonb_array_elements(p_rows) r
    loop
      if v_locality is null or length(btrim(v_locality)) = 0 then
        raise exception 'row with blank locality label';
      end if;

      insert into public.doe_locality_reports (run_id, doe_source_label, status)
      values (
        v_run_id,
        v_locality,
        case when exists (
          select 1 from jsonb_array_elements(p_rows) r
          where r->>'locality' = v_locality
            and (public.is_no_outlet_marker(r->>'min')
              or public.is_no_outlet_marker(r->>'max')
              or public.is_no_outlet_marker(r->>'common'))
        ) then 'no_outlet'::public.doe_locality_report_status
        else 'data'::public.doe_locality_report_status end
      );
    end loop;

    -- ---- 2. Price rows --------------------------------------------------
    for v_row in select * from jsonb_array_elements(p_rows)
    loop
      v_locality := v_row->>'locality';

      select id into v_report_id
      from public.doe_locality_reports
      where run_id = v_run_id and doe_source_label = v_locality;

      -- A no-outlet locality has nothing to price.
      continue when (
        select status from public.doe_locality_reports where id = v_report_id
      ) = 'no_outlet';

      v_min    := public.normalize_doe_price(v_row->>'min');
      v_max    := public.normalize_doe_price(v_row->>'max');
      v_common := public.normalize_doe_price(v_row->>'common');

      -- A brand with no published figures gets NO ROW. That is precisely what
      -- a blank source column means; inventing a zero would be a lie.
      continue when v_min is null and v_max is null and v_common is null;

      -- Per-fuel-type plausibility bounds. Kerosene legitimately trades far
      -- above gasoline, so a shared ceiling would reject valid DOE data.
      select min_plausible, max_plausible into v_lo, v_hi
      from public.fuel_types where code = v_row->>'fuel';

      if v_lo is null then
        raise exception 'unknown fuel type: %', v_row->>'fuel';
      end if;

      if (v_min    is not null and (v_min    < v_lo or v_min    > v_hi))
      or (v_max    is not null and (v_max    < v_lo or v_max    > v_hi))
      or (v_common is not null and (v_common < v_lo or v_common > v_hi)) then
        raise exception
          'price out of plausible bounds for % (allowed %-%): min=% max=% common=% [locality %, brand %]',
          v_row->>'fuel', v_lo, v_hi, v_min, v_max, v_common, v_locality, v_row->>'brand';
      end if;

      if v_min is not null and v_max is not null and v_min > v_max then
        raise exception 'min > max for % % at % (% > %)',
          v_locality, v_row->>'fuel', v_row->>'brand', v_min, v_max;
      end if;

      insert into public.doe_reference_prices
        (locality_report_id, fuel_type_code, brand_code, min_price, max_price, common_price)
      values
        (v_report_id, v_row->>'fuel', v_row->>'brand', v_min, v_max, v_common);
    end loop;

    -- ---- 3. Every registered locality must be accounted for --------------
    -- Zero rows for a registered locality is a FAILURE, not a valid report that
    -- the locality has no data. A genuine absence is published explicitly as
    -- "No LFRO"; silence means the source label was renamed, reformatted, or
    -- misspelled and our matching quietly missed it.
    for v_expected in
      select display_name, doe_source_label
      from public.localities
      where doe_region_code = p_region_code
    loop
      select count(distinct lr.doe_source_label) into v_match_count
      from public.doe_locality_reports lr
      where lr.run_id = v_run_id
        and public.normalize_locality_label(lr.doe_source_label)
          = public.normalize_locality_label(v_expected.doe_source_label);

      if v_match_count = 0 then
        raise exception
          'registered locality % (source label %) matched no rows in this document',
          v_expected.display_name, v_expected.doe_source_label;
      end if;

      -- More than one distinct source label normalizing to the same registry
      -- entry is ambiguous. Resolving it by picking one would risk attributing
      -- prices to the wrong town, which is worse than failing.
      if v_match_count > 1 then
        raise exception
          'ambiguous match for % (source label %): % distinct source labels matched',
          v_expected.display_name, v_expected.doe_source_label, v_match_count;
      end if;

      -- A locality reported as having data but carrying no price rows is an
      -- empty shell — the same silent-failure shape as matching nothing.
      select count(*) into v_price_rows
      from public.doe_reference_prices p
      join public.doe_locality_reports lr on lr.id = p.locality_report_id
      where lr.run_id = v_run_id
        and lr.status = 'data'
        and public.normalize_locality_label(lr.doe_source_label)
          = public.normalize_locality_label(v_expected.doe_source_label);

      if v_price_rows = 0
         and exists (
           select 1 from public.doe_locality_reports lr
           where lr.run_id = v_run_id
             and lr.status = 'data'
             and public.normalize_locality_label(lr.doe_source_label)
               = public.normalize_locality_label(v_expected.doe_source_label)
         ) then
        raise exception
          'registered locality % reported data but produced no price rows',
          v_expected.display_name;
      end if;
    end loop;

    update public.doe_load_runs
       set status = 'succeeded', recorded_at = now()
     where id = v_run_id;

  exception when others then
    -- Work rolls back to this block's implicit savepoint; the run row inserted
    -- before the block survives so the failure stays reviewable.
    update public.doe_load_runs
       set status = 'failed', failure_reason = sqlerrm
     where id = v_run_id;
  end;

  return v_run_id;
end;
$$;

comment on function public.load_doe_reference_prices is
  'Loads flat DOE price rows into run -> locality report -> price rows. Returns '
  'the run id. On any validation failure the work is rolled back and the run is '
  'marked failed with a reason; readers only ever see succeeded runs.';

revoke all on function public.load_doe_reference_prices(text,text,date,date,text,jsonb) from public, anon, authenticated;
