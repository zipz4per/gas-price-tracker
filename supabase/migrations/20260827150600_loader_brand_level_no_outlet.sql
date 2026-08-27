-- Loader, corrected for brand-level "No LFRO".
--
-- Replaces the version that treated any "No LFRO" cell as a locality-level
-- fact. See 20260827150500_brand_level_no_outlet.sql for why that was wrong.
--
-- Now: a "No LFRO" cell produces a no_outlet ROW for that brand, and the
-- locality is marked no_outlet only when every one of its brands is.

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
  v_no_outlet   boolean;
  v_expected    record;
  v_match_count int;
  v_reported    int;
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

    -- ---- 1. One report per locality; status decided later from its brands ---
    for v_locality in
      select distinct r->>'locality' from jsonb_array_elements(p_rows) r
    loop
      if v_locality is null or length(btrim(v_locality)) = 0 then
        raise exception 'row with blank locality label';
      end if;

      insert into public.doe_locality_reports (run_id, doe_source_label, status)
      values (v_run_id, v_locality, 'data');
    end loop;

    -- ---- 2. Price rows -----------------------------------------------------
    for v_row in select * from jsonb_array_elements(p_rows)
    loop
      v_locality := v_row->>'locality';

      select id into v_report_id
      from public.doe_locality_reports
      where run_id = v_run_id and doe_source_label = v_locality;

      -- "No LFRO" in ANY of this brand's cells means the brand has no station
      -- in this locality. It is recorded, not discarded: it is a different and
      -- more useful fact than a missing price.
      v_no_outlet := public.is_no_outlet_marker(v_row->>'min')
                  or public.is_no_outlet_marker(v_row->>'max')
                  or public.is_no_outlet_marker(v_row->>'common');

      if v_no_outlet then
        insert into public.doe_reference_prices
          (locality_report_id, fuel_type_code, brand_code, brand_presence,
           min_price, max_price, common_price)
        values
          (v_report_id, v_row->>'fuel', v_row->>'brand', 'no_outlet', null, null, null)
        on conflict (locality_report_id, fuel_type_code, brand_code) do nothing;
        continue;
      end if;

      v_min    := public.normalize_doe_price(v_row->>'min');
      v_max    := public.normalize_doe_price(v_row->>'max');
      v_common := public.normalize_doe_price(v_row->>'common');

      -- A brand that operates here but published no figure gets NO ROW — that
      -- is what a blank column means, and it stays distinct from no_outlet.
      continue when v_min is null and v_max is null and v_common is null;

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
        (locality_report_id, fuel_type_code, brand_code, brand_presence,
         min_price, max_price, common_price)
      values
        (v_report_id, v_row->>'fuel', v_row->>'brand', 'reported', v_min, v_max, v_common);
    end loop;

    -- ---- 3. Derive locality no_outlet from its brands -----------------------
    -- A locality has no retail outlet only when EVERY brand in it is marked so.
    update public.doe_locality_reports lr
       set status = 'no_outlet'
     where lr.run_id = v_run_id
       and exists (
         select 1 from public.doe_reference_prices p
         where p.locality_report_id = lr.id
       )
       and not exists (
         select 1 from public.doe_reference_prices p
         where p.locality_report_id = lr.id
           and p.brand_presence = 'reported'
       );

    -- ---- 4. Every registered locality must be accounted for -----------------
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

      if v_match_count > 1 then
        raise exception
          'ambiguous match for % (source label %): % distinct source labels matched',
          v_expected.display_name, v_expected.doe_source_label, v_match_count;
      end if;

      -- A locality still marked 'data' but carrying no reported prices is an
      -- empty shell: the same silent-failure shape as matching nothing.
      select count(*) into v_reported
      from public.doe_reference_prices p
      join public.doe_locality_reports lr on lr.id = p.locality_report_id
      where lr.run_id = v_run_id
        and lr.status = 'data'
        and p.brand_presence = 'reported'
        and public.normalize_locality_label(lr.doe_source_label)
          = public.normalize_locality_label(v_expected.doe_source_label);

      if v_reported = 0
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
    update public.doe_load_runs
       set status = 'failed', failure_reason = sqlerrm
     where id = v_run_id;
  end;

  return v_run_id;
end;
$$;

revoke all on function public.load_doe_reference_prices(text,text,date,date,text,jsonb) from public, anon, authenticated;
