-- Announced movements in the price of fuel.
--
-- Philippine oil companies adjust prices most Tuesdays, announced the evening
-- before and effective at six in the morning. Between one observation at a pump
-- and today, the price has moved by the sum of these; that sum is what lets an
-- observed price stay useful past the day it was observed.
--
-- This change defines what an adjustment IS and what it does. It does not
-- produce one: add-price-adjustment-feed is the writer, and until it lands this
-- table stays empty and every observation ages out on the day limit alone.
--
-- The amount is SIGNED. A rollback is a negative adjustment, not a positive one
-- carrying a direction word beside it. Storing magnitude and direction
-- separately creates a second field that can be read wrong, and reading it wrong
-- moves every derived price in the system the wrong way.
--
-- Zero is not an adjustment. A week with no announcement is represented by the
-- absence of a row, never by a row of zero - the two are different facts and the
-- feed's run records are where the difference is recorded.

create table public.price_adjustments (
  id uuid primary key default gen_random_uuid(),

  fuel_type_code text not null
    references public.fuel_types (code),

  -- Pesos per litre, signed. Negative is a rollback.
  amount numeric(6,2) not null
    constraint price_adjustments_amount_not_zero check (amount <> 0),

  -- When the new price takes effect, not when it was announced or read.
  -- Taken from the announcement itself; the weekly cycle is a convention that
  -- announcements usually follow and sometimes do not.
  effective_at timestamptz not null,

  -- When the announcement was published.
  announced_at timestamptz,

  -- Where this was read. add-price-adjustment-feed replaces this with proper
  -- multi-source attribution; until then it is a free-text note.
  source text,

  recorded_at timestamptz not null default now(),

  -- One adjustment per fuel type per effective instant.
  --
  -- This is load-bearing rather than tidy. Derived prices are computed on read
  -- as the last observation plus every adjustment effective since, so a
  -- duplicate row would move every price descending from it twice - silently,
  -- everywhere, and with nothing inside the system able to notice.
  constraint price_adjustments_unique_per_fuel_and_instant
    unique (fuel_type_code, effective_at)
);

comment on table public.price_adjustments is
  'Announced per-litre movements in the price of fuel, signed, one per fuel type '
  'per effective instant. Written by add-price-adjustment-feed; read on every '
  'price query to carry observations forward.';

comment on column public.price_adjustments.amount is
  'Pesos per litre, signed. Negative is a rollback. Never zero: a week with no '
  'announcement is the absence of a row.';

create index price_adjustments_fuel_effective_idx
  on public.price_adjustments (fuel_type_code, effective_at desc);
