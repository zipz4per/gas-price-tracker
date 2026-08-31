-- The three kinds of price a station can show, and the shape a station's price
-- is returned in.
--
-- Every figure the system supplies says what kind of figure it is. A price
-- observed at a pump, a price carried forward across an announced adjustment,
-- and a locality-wide range published by DOE are three different claims, and a
-- consumer that receives a bare number will present whichever one it gets as
-- though it were the first.

create type public.price_kind as enum (
  'observed',   -- someone reported this price at this station
  'derived',    -- an earlier observation here, carried across announced adjustments
  'reference'   -- the DOE locality-wide range; no observation at this station
);

comment on type public.price_kind is
  'What kind of claim a displayed price is. Null alongside a price means there '
  'is no figure at all, and absence_reason says why.';

-- The sentence that says what the figure is.
--
-- A DOMAIN rather than a plain text attribute, because Postgres composite types
-- cannot carry NOT NULL on their attributes but DO enforce a domain's
-- constraints on assignment - a row(...)::station_price_result with a null here
-- raises rather than returning quietly. The existing station_reference_result
-- makes the same promise in a comment and cannot keep it; this one can.
--
-- The empty-string check is the same guarantee against the other way of
-- supplying nothing.
create domain public.price_basis as text
  not null
  constraint price_basis_not_blank check (length(btrim(value)) > 0);

comment on domain public.price_basis is
  'A non-empty sentence stating what a figure is, or why there is none. '
  'Enforced, not merely documented: a null or blank raises on assignment.';

create type public.station_price_result as (
  -- The station.
  station_id           uuid,
  provider_place_id    text,
  station_name         text,
  brand_code           text,
  brand_display        text,
  address              text,
  latitude             numeric(9,6),
  longitude            numeric(9,6),
  locality             text,

  -- The fuel.
  fuel_type            text,
  fuel_display         text,

  -- What kind of figure this is, and the sentence that says so. The sentence is
  -- present in every row, including rows with no figure at all.
  price_kind           public.price_kind,
  price_basis          public.price_basis,
  absence_reason       public.reference_absence_reason,

  -- The figure, when it is a single price: observed or derived.
  price                numeric(6,2),

  -- How much is behind an observed or derived figure.
  report_count         integer,
  newest_report_at     timestamptz,

  -- Where a derived figure came from, so its distance from an observation is
  -- visible rather than implied.
  baseline_price       numeric(6,2),
  baseline_observed_at timestamptz,
  adjustments_applied  integer,

  -- The figure, when it is a range: reference.
  min_price            numeric(6,2),
  max_price            numeric(6,2),
  common_price         numeric(6,2),

  -- How much the reference range has been shifted by announced adjustments
  -- since the reporting period ended. Null when it has not been shifted.
  reference_shifted_by numeric(6,2),

  -- Reference provenance.
  doe_source_locality  text,
  proxy_source         text,
  period_start         date,
  period_end           date,
  period_label         text,
  source_url           text,

  -- ODbL. Station data is extracted from OpenStreetMap and every surface that
  -- displays it must credit the source, so the credit travels with the data.
  station_attribution  text
);

comment on type public.station_price_result is
  'One row per station per fuel type. price_kind and price_basis always say '
  'what the figure is; a null price_kind means there is no figure and '
  'absence_reason says why. A station is returned in every case, never omitted.';
