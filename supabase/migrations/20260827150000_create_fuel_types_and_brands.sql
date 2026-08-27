-- Lookup tables for DOE reference prices: the fuel types DOE publishes and the
-- brand columns its reports carry.

-- ---------------------------------------------------------------------------
-- fuel_types
--
-- Plausibility bounds are PER FUEL TYPE, not one global range. The PRD proposes
-- a single ₱30–₱120 sanity bound for all fuels. Kerosene was observed trading
-- between ₱113 and ₱134 in the two live reports inspected while planning this
-- change, so a global ₱120 ceiling would reject valid DOE data every week.
--
-- This matters beyond ingestion: the same bound is proposed for crowdsourced
-- submissions, where a global ceiling would reject honest kerosene reports from
-- real users and look like a bug in the app rather than in the bound.
-- ---------------------------------------------------------------------------
create table public.fuel_types (
  code        text primary key,
  display_name text not null,
  -- Sort order for presentation: DOE lists gasoline grades descending by octane,
  -- then diesel, then kerosene.
  sort_order  smallint not null,
  min_plausible numeric(6,2) not null,
  max_plausible numeric(6,2) not null,
  created_at  timestamptz not null default now(),

  constraint fuel_types_code_not_blank check (length(btrim(code)) > 0),
  constraint fuel_types_bounds_ordered check (min_plausible < max_plausible),
  constraint fuel_types_bounds_positive check (min_plausible > 0)
);

comment on table public.fuel_types is
  'Fuel types published by DOE, with per-fuel-type plausibility bounds used to '
  'validate loaded prices. Bounds are per fuel because kerosene trades far '
  'above gasoline and would fail a shared ceiling.';
comment on column public.fuel_types.max_plausible is
  'Upper validation bound. Kerosene''s exceeds ₱134, the highest value observed '
  'in real DOE reports.';

insert into public.fuel_types (code, display_name, sort_order, min_plausible, max_plausible) values
  ('RON_100',     'RON 100',     10, 30.00, 150.00),
  ('RON_97',      'RON 97',      20, 30.00, 150.00),
  ('RON_95',      'RON 95',      30, 30.00, 150.00),
  ('RON_91',      'RON 91',      40, 30.00, 150.00),
  ('DIESEL',      'Diesel',      50, 30.00, 150.00),
  ('DIESEL_PLUS', 'Diesel Plus', 60, 30.00, 150.00),
  -- Observed ₱113.00–₱134.67 across the NCR and CALABARZON reports. The ceiling
  -- is set well clear of that so a genuine price rise is not mistaken for a
  -- transcription error.
  ('KEROSENE',    'Kerosene',    70, 50.00, 200.00);

-- ---------------------------------------------------------------------------
-- brands
--
-- One row per brand COLUMN in the source reports, plus two non-brand entries:
--
--   INDEPENDENT  DOE's aggregate column for unbranded/independent dealers
--   OVERALL      reserved sentinel for the all-brands range a row publishes;
--                not a brand, but stored as one so every price row has the
--                same shape and a changing brand set stays a data concern
--
-- The brand set differs between NCR and CALABARZON and DOE can add or drop
-- columns without notice, which is why brands are rows rather than columns on
-- the price table.
-- ---------------------------------------------------------------------------
create table public.brands (
  code         text primary key,
  display_name text not null,
  -- false for OVERALL, which is an aggregate rather than a retailer.
  is_retailer  boolean not null default true,
  sort_order   smallint not null,
  created_at   timestamptz not null default now(),

  constraint brands_code_not_blank check (length(btrim(code)) > 0)
);

comment on table public.brands is
  'Brand columns published in DOE reports, plus the INDEPENDENT aggregate and '
  'the reserved OVERALL sentinel carrying a row''s all-brands range.';
comment on column public.brands.is_retailer is
  'false for OVERALL, which is an aggregate range and not a retailer.';

insert into public.brands (code, display_name, is_retailer, sort_order) values
  ('PETRON',      'Petron',      true,  10),
  ('SHELL',       'Shell',       true,  20),
  ('CALTEX',      'Caltex',      true,  30),
  ('PHOENIX',     'Phoenix',     true,  40),
  ('TOTAL',       'Total',       true,  50),
  ('UNIOIL',      'Unioil',      true,  60),
  ('SEAOIL',      'Seaoil',      true,  70),
  ('FLYING_V',    'Flying V',    true,  80),
  ('PTT',         'PTT',         true,  90),
  ('INDEPENDENT', 'Independent', true, 100),
  ('OVERALL',     'Overall',     false, 999);
