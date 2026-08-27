-- The DOE reference price load hierarchy.
--
--   doe_load_runs         one per source document processed
--     └─ doe_locality_reports   one per locality within that run
--          └─ doe_reference_prices   one per fuel type × brand
--
-- Readers only ever see rows belonging to a run marked 'succeeded'. That is
-- what makes "a failed or partial load must not destroy good data" structurally
-- true rather than a rule someone has to remember: a run accumulates invisibly
-- and becomes visible atomically, or never. Nothing is overwritten in place, so
-- the previous period stays queryable throughout.

create type public.doe_load_run_status as enum ('in_progress', 'succeeded', 'failed');
create type public.doe_locality_report_status as enum ('data', 'no_outlet');

comment on type public.doe_load_run_status is
  'in_progress: accumulating, invisible to readers. succeeded: visible. '
  'failed: permanently invisible, retained for operator review.';
comment on type public.doe_locality_report_status is
  'data: the source published figures. no_outlet: the source explicitly marked '
  'this locality as having no liquid fuel retail outlet (DOE prints "No LFRO").';

-- ---------------------------------------------------------------------------
-- doe_load_runs
-- ---------------------------------------------------------------------------
create table public.doe_load_runs (
  id              uuid primary key default gen_random_uuid(),
  doe_region_code text not null references public.doe_regions (code),
  status          public.doe_load_run_status not null default 'in_progress',

  -- Provenance. source_url is the exact document the figures came from.
  source_url      text not null,

  -- Reporting period as explicit dates. NOT assumed to be a week: NCR publishes
  -- a 7-day span, CALABARZON a 3-day monitoring window. Storing a start and end
  -- keeps both honest.
  period_start    date not null,
  period_end      date not null,
  -- The period wording exactly as the document expresses it, e.g.
  -- "For the week of August 18-24, 2026" or "DATE MONITORING: August 18 - 20, 2026".
  -- Retained so the app can render what the document actually said rather than
  -- asserting a week.
  period_label    text not null,

  -- Why a run failed, for operator review. Required when status = 'failed'.
  failure_reason  text,

  started_at      timestamptz not null default now(),
  recorded_at     timestamptz,

  constraint doe_load_runs_source_url_not_blank check (length(btrim(source_url)) > 0),
  constraint doe_load_runs_period_label_not_blank check (length(btrim(period_label)) > 0),
  constraint doe_load_runs_period_ordered check (period_start <= period_end),
  -- A failed run without a reason cannot be reviewed, which defeats the point
  -- of recording the failure at all.
  constraint doe_load_runs_failure_has_reason check (
    (status = 'failed' and failure_reason is not null and length(btrim(failure_reason)) > 0)
    or (status <> 'failed' and failure_reason is null)
  ),
  -- A succeeded run must record when it became visible.
  constraint doe_load_runs_succeeded_has_recorded_at check (
    (status = 'succeeded' and recorded_at is not null)
    or (status <> 'succeeded')
  )
);

comment on table public.doe_load_runs is
  'One row per DOE document processed. Only runs with status = succeeded are '
  'visible to readers; this is the atomicity boundary.';

-- ---------------------------------------------------------------------------
-- doe_locality_reports
-- ---------------------------------------------------------------------------
create table public.doe_locality_reports (
  id                uuid primary key default gen_random_uuid(),
  run_id            uuid not null references public.doe_load_runs (id) on delete cascade,

  -- The locality label as the DOE document prints it, e.g. "Tanauan City" or
  -- "Taguig Cty". Prices are keyed by the SOURCE locality, not the app
  -- locality: Malvar's figures ARE Tanauan City's figures, and storing them
  -- under Malvar would duplicate every row per proxy consumer.
  doe_source_label  text not null,
  status            public.doe_locality_report_status not null,

  constraint doe_locality_reports_label_not_blank check (length(btrim(doe_source_label)) > 0),
  -- One report per locality per run; a duplicate would make "which rows are
  -- current" ambiguous.
  constraint doe_locality_reports_run_locality_unique unique (run_id, doe_source_label)
);

comment on table public.doe_locality_reports is
  'One row per locality within a load run, keyed by the locality label as the '
  'DOE document prints it. Proxy resolution happens at read time, not here.';

-- ---------------------------------------------------------------------------
-- doe_reference_prices
-- ---------------------------------------------------------------------------
create table public.doe_reference_prices (
  id                 uuid primary key default gen_random_uuid(),
  locality_report_id uuid not null references public.doe_locality_reports (id) on delete cascade,
  fuel_type_code     text not null references public.fuel_types (code),
  brand_code         text not null references public.brands (code),

  -- All three are nullable. DOE expresses missing data four different ways
  -- (an unavailable marker, the literal "None", "0.00", and "No LFRO"); every
  -- one of them normalizes to NULL here rather than to a number. A zero-peso
  -- price is not a price.
  min_price          numeric(6,2),
  max_price          numeric(6,2),
  common_price       numeric(6,2),

  constraint doe_reference_prices_min_le_max check (
    min_price is null or max_price is null or min_price <= max_price
  ),
  constraint doe_reference_prices_prices_positive check (
    (min_price    is null or min_price    > 0) and
    (max_price    is null or max_price    > 0) and
    (common_price is null or common_price > 0)
  ),
  -- A row carrying no figures at all is noise; absence is represented by the
  -- row not existing, which is what a blank source column actually means.
  constraint doe_reference_prices_not_entirely_empty check (
    min_price is not null or max_price is not null or common_price is not null
  ),
  constraint doe_reference_prices_unique_cell unique (locality_report_id, fuel_type_code, brand_code)
);

comment on table public.doe_reference_prices is
  'One row per fuel type × brand within a locality report. A brand with no '
  'published figures has NO ROW — that is what a blank source column means.';
comment on column public.doe_reference_prices.brand_code is
  'References brands.code. The reserved OVERALL sentinel carries the row''s '
  'all-brands range and is not attributed to any retailer.';

-- ---------------------------------------------------------------------------
-- Indexes for the read path: locality label + fuel type, scoped to the latest
-- succeeded run.
-- ---------------------------------------------------------------------------
create index doe_load_runs_succeeded_period_idx
  on public.doe_load_runs (doe_region_code, period_end desc)
  where status = 'succeeded';

create index doe_locality_reports_label_idx
  on public.doe_locality_reports (public.normalize_locality_label(doe_source_label));

create index doe_locality_reports_run_idx
  on public.doe_locality_reports (run_id);

create index doe_reference_prices_lookup_idx
  on public.doe_reference_prices (locality_report_id, fuel_type_code);
