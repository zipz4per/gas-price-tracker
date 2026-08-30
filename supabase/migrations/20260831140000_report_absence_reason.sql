-- Say WHICH absence it is.
--
-- Four situations produce "no reference price" and the read paths reported all
-- four as the fourth -- the only one that is a statement about what DOE
-- published. With an empty database the system answered "DOE does not report
-- Petron for RON_95 in Taguig City", which is false: DOE reports it perfectly
-- well, and what had happened is that nothing had ever been ingested.
--
-- This is the same failure fix-unrecognised-read-inputs corrected one level
-- along. That change could not distinguish a request it could not parse from
-- one it understood and had no answer for. This path understands the question
-- and then guesses at why it has no answer.
--
-- Nothing is stored to fix it. doe_load_runs already records whether any load
-- succeeded, and doe_locality_reports records what each one covered.

create type public.reference_absence_reason as enum (
  -- Ours. No load has ever succeeded, so the silence is our ingestion's.
  'no_data_ingested',
  -- Ours, narrower. Loads exist; none covered this locality.
  'locality_not_covered',
  -- The source's. The locality was reported, this fuel type was not.
  'fuel_type_not_reported',
  -- The source's, per brand. The report covered this locality and fuel type and
  -- carried no figure for this brand. Only a caller holding a brand can observe
  -- it, so get_doe_reference_prices never emits it; the station read path does.
  'brand_not_reported',
  -- Ours, and not about DOE at all: our rules could not resolve the station's
  -- provider name to a registered brand, so there is no brand to look up.
  'brand_not_identified'
);

comment on type public.reference_absence_reason is
  'Why a reference figure is absent. The first two are facts about our own '
  'ingestion, the next two about what the source published, the last about our '
  'own brand resolution. Reporting a more specific reason than the evidence '
  'supports is the defect this type exists to prevent.';

-- Null exactly when has_data is true. A no-data row without a reason is not
-- representable, which is what stops the reason being an optional extra a
-- caller can forget to select.
alter type public.doe_price_result
  add attribute absence_reason public.reference_absence_reason cascade;

comment on type public.doe_price_result is
  'One row per brand, plus the OVERALL range. A single row with has_data = '
  'false means there are no figures, and absence_reason says why. A brand the '
  'report did not carry has no row at all: retrieval is not asked about a '
  'brand, so it does not answer about one.';

create or replace function public.get_doe_reference_prices(p_locality text, p_fuel_type text)
 RETURNS SETOF doe_price_result
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_loc       record;
  v_report    record;
  v_fuel_code text;
  v_reason    public.reference_absence_reason;
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
    -- Two different facts share this branch, and telling them apart is the
    -- whole point of this change. If NOTHING has ever loaded, the absence is
    -- ours; if loads exist and simply never covered this town, it is the
    -- source's. Reporting the second when the first is true blames DOE for an
    -- ingestion that never ran.
    --
    -- Checked in this order because they nest: with no succeeded run at all
    -- every locality is trivially uncovered, and the more general statement is
    -- the only one the evidence supports.
    if exists (select 1 from public.doe_load_runs r where r.status = 'succeeded') then
      v_reason := 'locality_not_covered';
    else
      v_reason := 'no_data_ingested';
    end if;

    return query select
      v_loc.display_name, v_loc.doe_source_label, v_loc.proxy_source_display_name,
      v_fuel_code, null::text, null::public.doe_brand_presence,
      null::numeric(6,2), null::numeric(6,2), null::numeric(6,2),
      null::date, null::date, null::text, null::timestamptz, null::text,
      false, v_reason;
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
      -- Cast explicitly: a bare literal here is text, and RETURN QUERY
      -- checks the row against the composite type by position and type.
      false, 'fuel_type_not_reported'::public.reference_absence_reason;
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
      true, null::public.reference_absence_reason
    from public.doe_reference_prices p
    join public.brands b on b.code = p.brand_code
    where p.locality_report_id = v_report.id
      and p.fuel_type_code = v_fuel_code
    order by b.sort_order, p.brand_code;
end;
$function$

;
