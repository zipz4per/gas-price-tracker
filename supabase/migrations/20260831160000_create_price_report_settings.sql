-- Tunable limits for the price report path, in one row.
--
-- Four numbers govern behaviour a user can feel: how close you must be to
-- report, how long an observation stays believable, and how often one station
-- can be reported. Each was chosen with a reason recorded in the change's
-- design, and each is expected to move once there is real traffic to set it by.
-- Numbers like that do not belong inline in a function body, where changing one
-- means a migration that rewrites logic and where the current value is
-- discoverable only by reading the logic.
--
-- Single row, enforced by a boolean primary key. A settings table that can hold
-- two rows eventually holds two rows, and every reader then needs a rule for
-- which one it meant.

create table public.price_report_settings (
  id boolean primary key default true,

  -- How near a device must be to a station to report a price there.
  --
  -- 150 m. A forecourt is roughly 100 m across and phone GPS is 5-20 m in the
  -- open and worse among tall buildings, so a tighter radius rejects people who
  -- are genuinely standing on the concrete. It does not need to be tight,
  -- because it is not identifying the station: the provider's own data puts
  -- competing brands 27-40 m apart and gives 22 of 96 stations a neighbour
  -- inside 100 m. The submitter chooses from the candidates in range.
  proximity_radius_metres integer not null default 150
    constraint price_report_settings_radius_positive check (proximity_radius_metres > 0),

  -- How far an observation may be carried before it is no longer shown.
  --
  -- Two conditions, and the second is not redundant. Each adjustment applied to
  -- a baseline adds error, so four of them - about a month of weekly cycles -
  -- is the point where a derived figure stops being better than the locality
  -- range it falls back to. But the adjustment count only means anything while
  -- adjustments are being ingested: if the feed dies, no adjustments accrue,
  -- the count stays at zero, and a six-month-old observation would keep
  -- presenting itself as freshly observed. The day limit is what ages an
  -- observation out when nothing is watching the feed.
  carry_forward_max_adjustments integer not null default 4
    constraint price_report_settings_adjustments_not_negative check (carry_forward_max_adjustments >= 0),
  carry_forward_max_days integer not null default 35
    constraint price_report_settings_days_positive check (carry_forward_max_days > 0),

  -- How many reports one station and fuel type may accept in an hour.
  --
  -- Without accounts there is no per-person limit, so this bounds the rate at
  -- which anyone can churn a station's displayed value. It does not stop a
  -- determined submitter standing at the pump; because reports are retained and
  -- the newest wins, the next honest report corrects it.
  station_fuel_reports_per_hour integer not null default 6
    constraint price_report_settings_rate_cap_positive check (station_fuel_reports_per_hour > 0),

  constraint price_report_settings_single_row check (id)
);

comment on table public.price_report_settings is
  'One row. Tunable limits for the price report path: proximity radius, '
  'carry-forward bounds, and the per-station hourly rate cap.';

insert into public.price_report_settings (id) values (true);

-- RLS on with no policy at all. The read and submission paths are SECURITY
-- DEFINER and read this table as their owner, so no client needs direct access;
-- and a table with no policy cannot have one mis-scoped later. Same reasoning as
-- the write side of the station registry.
alter table public.price_report_settings enable row level security;
