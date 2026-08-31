-- What someone standing at a pump says a station is charging.
--
-- This is the only source that can answer the question the app exists to answer.
-- The reference data is published by brand across a whole municipality: on a
-- Lipa City map of 52 stations, RON 95 resolves to three distinct numbers, so a
-- map that looks like it compares stations is comparing brands. Only an
-- observation at a forecourt distinguishes that forecourt from its neighbours.
--
-- Reports are retained rather than overwritten. The newest is displayed; the
-- earlier ones are the record of how a station's price moved, and they are also
-- what makes a spammed value recoverable rather than destructive.
--
-- NOTE ON WHAT IS ABSENT HERE. There is no latitude, no longitude, and no
-- geometry column, and that is the design rather than an omission. Proximity is
-- checked server-side from coordinates passed as arguments to the submission
-- function; the function keeps the verdict and discards the position. NFR-5 says
-- no location is stored more precisely than needed, and the precision needed
-- once the check has run is none. Adding a column here to "keep it for later"
-- would quietly convert a privacy property into a data retention question.

create table public.price_reports (
  id uuid primary key default gen_random_uuid(),

  station_id uuid not null
    references public.stations (id) on delete cascade,

  fuel_type_code text not null
    references public.fuel_types (code),

  -- Pesos per litre as read off the pump.
  price numeric(6,2) not null,

  -- When the price was observed. Distinct from recorded_at so that a report
  -- submitted a few minutes after the fact is still dated to the observation.
  observed_at timestamptz not null default now(),

  -- The proximity verdict, and only the verdict.
  --
  -- Constrained to true because a report that failed the check is rejected
  -- outright rather than stored as unverified. The column exists so that the
  -- fact a check happened travels with the row; the constraint exists so that a
  -- future writer cannot start inserting unverified rows without changing the
  -- schema deliberately.
  proximity_verified boolean not null default true
    constraint price_reports_proximity_verified check (proximity_verified),

  recorded_at timestamptz not null default now()
);

comment on table public.price_reports is
  'Crowdsourced price observations, one per station per fuel type per '
  'submission. The newest is displayed; earlier reports are retained. Holds no '
  'submitter location: the proximity check keeps its verdict and discards the '
  'coordinates.';

comment on column public.price_reports.proximity_verified is
  'PRIVACY: the entire retained result of the proximity check. The submitting '
  'device''s coordinates are arguments to submit_price_report and are never '
  'written.';

-- Serves both the newest-report lookup and the per-station hourly rate cap.
create index price_reports_station_fuel_observed_idx
  on public.price_reports (station_id, fuel_type_code, observed_at desc);
