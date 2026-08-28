-- Teach the reference-price read path to say "I did not understand that."
--
-- It could not. Asked for a fuel type it did not recognise, it answered
-- has_data = false — the same well-formed reply it gives when a locality
-- genuinely has no figures for a real fuel type. 'RON 95' reported no data for
-- Malvar while 'RON_95' returned seven priced rows, and 'BANANA' reported no
-- data with equal confidence. Asked for an unregistered locality it returned
-- an empty set, which reports nothing at all, though locality-registry
-- requires that such a locality be REPORTED as not covered.
--
-- Filed as openspec/bugs/doe-fuel-type-not-recognised.
--
-- The original header of this function says the quiet part:
--
--     None of those mistakes raises an error. They produce plausible wrong
--     answers, so the only reliable defence is making the wrong query
--     impossible to express.
--
-- That reasoning was applied to proxy attribution, run visibility, and absent
-- brands, and not to the function's own arguments. This migration extends it
-- to the front door.
--
--   request                        before                    after
--   ─────────────────────────────────────────────────────────────────────────
--   Malvar, RON_95                 7 rows                    7 rows
--   Malvar, RON 95                 1 row, has_data = false   7 rows
--   Malvar, KEROSENE (no figures)  1 row, has_data = false   1 row, has_data = false
--   Malvar, BANANA                 1 row, has_data = false   error
--   Atlantis, RON_95               0 rows                    error
--
-- Absence is untouched. has_data = false still means "understood, and there is
-- nothing to show", which is why it cannot also mean "not understood": a
-- consumer already reads it the first way.

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
  v_loc       record;
  v_report    record;
  v_fuel_code text;
begin
  -- Recognise the arguments BEFORE answering. An unrecognised argument raises
  -- rather than returning a row, because a third state in the result would
  -- repeat the mistake being fixed: a caller who ignores has_data today would
  -- ignore a `recognised` flag tomorrow, and the response would again be
  -- well-formed and wrong. An error cannot be ignored into a plausible answer.
  --
  -- Matched through normalize_locality_label(), which lowercases, maps
  -- punctuation to a space, collapses whitespace and trims — so 'RON 95',
  -- 'ron_95' and 'RON_95' all reach RON_95. Its name mentions localities and
  -- its behaviour does not; a second normalizer for fuel codes would put two
  -- definitions of "the same string" in one function, which is how the
  -- original asymmetry arose. It is deliberately NOT fuzzy, so a value that
  -- normalizes to no registered code is unrecognised rather than rounded to
  -- its nearest neighbour.
  select ft.code into v_fuel_code
  from public.fuel_types ft
  where public.normalize_locality_label(ft.code)
      = public.normalize_locality_label(p_fuel_type);

  if not found then
    raise exception using
      errcode = '22023',  -- invalid_parameter_value; PostgREST answers 400
      message = format('unrecognised fuel type: %L', p_fuel_type),
      detail  = format('registered fuel types are %s',
                       (select string_agg(ft.code, ', ' order by ft.code)
                          from public.fuel_types ft)),
      hint    = 'Fuel types match case-insensitively with punctuation treated '
                'as separation, so RON 95, ron_95 and RON_95 all resolve. '
                'Matching is not fuzzy.';
  end if;

  -- Registered localities only. An unregistered locality is not covered, which
  -- is a different fact from having no data — and saying so out loud is what
  -- locality-registry means by "the system reports that the locality is not
  -- covered". Returning an empty set reported nothing: it was indistinguishable
  -- from a query that matched no rows.
  select l.display_name, l.doe_source_label, l.sourcing_mode, l.proxy_source_display_name
    into v_loc
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
  --
  -- Every row below carries v_fuel_code, the REGISTERED code, rather than
  -- p_fuel_type as requested. Echoing the input makes the response a mirror; a
  -- caller asking for 'RON 95' would otherwise get their own spelling back as
  -- though the system had endorsed it, and a client storing what it received
  -- would store the spelling instead of the code.
  if not found then
    return query select
      v_loc.display_name, v_loc.doe_source_label, v_loc.proxy_source_display_name,
      v_fuel_code, null::text, null::public.doe_brand_presence,
      null::numeric(6,2), null::numeric(6,2), null::numeric(6,2),
      null::date, null::date, null::text, null::timestamptz, null::text,
      false;
    return;
  end if;

  -- Data exists for the locality but not for this fuel type. Same explicit
  -- no-data row: figures are never borrowed across fuel types, so a locality
  -- with Diesel but no Kerosene reports no Kerosene rather than Diesel's price.
  --
  -- This branch is now reached only by a RECOGNISED fuel type with no figures.
  -- It used to swallow every unrecognised string as well, and the comment
  -- above — correct for the half it describes — is what made the other half
  -- invisible.
  if not exists (
    select 1 from public.doe_reference_prices p
    where p.locality_report_id = v_report.id
      and p.fuel_type_code = v_fuel_code
  ) then
    return query select
      v_loc.display_name, v_loc.doe_source_label, v_loc.proxy_source_display_name,
      v_fuel_code, null::text, null::public.doe_brand_presence,
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
      and p.fuel_type_code = v_fuel_code
    order by b.sort_order, p.brand_code;
end;
$$;

comment on function public.get_doe_reference_prices(text, text) is
  'Reference prices for a locality and fuel type. Rejects an unrecognised '
  'locality or fuel type rather than answering; resolves proxy sourcing, '
  'restricts to the latest succeeded run, and returns an explicit has_data = '
  'false row when the request was understood and there is nothing to show. '
  'Stale data is served with its period rather than withheld.';
