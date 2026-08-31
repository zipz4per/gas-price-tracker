-- Checking the feed against the only independent measurement of the same thing.
--
-- Once adjustments drive displayed prices, the system is a closed loop: an
-- observation plus a series of deltas. If an amount is misread, every price
-- descending from it moves together and no comparison inside the system reveals
-- it, because everything being compared is downstream of the same wrong number.
--
-- DOE measures the same quantity independently. Between two of its reporting
-- periods, the locality-wide midpoint should have moved by roughly the sum of
-- the adjustments announced over that interval. When it has not, something is
-- wrong with the feed, the parser, the mapping, or the reference data - and
-- which of those it is cannot be told from the divergence alone, so nothing is
-- corrected automatically.
--
-- This works from the first week with no crowdsourced data at all, which is why
-- it belongs here rather than waiting for traffic.

create table public.adjustment_feed_settings (
  id boolean primary key default true,

  -- How far the feed and the reference may disagree before it is surfaced.
  --
  -- P1.50 is set to catch order-of-magnitude and sign errors, which are the
  -- failures that matter: a P1.20 read as P0.12, or a rollback read as a hike.
  -- A twenty-centavo misread is inside the error the carry-forward limit
  -- already tolerates and is not worth a false alarm.
  divergence_threshold numeric(6,2) not null default 1.50
    constraint adjustment_feed_settings_threshold_positive check (divergence_threshold > 0),

  constraint adjustment_feed_settings_single_row check (id)
);

insert into public.adjustment_feed_settings (id) values (true);

alter table public.adjustment_feed_settings enable row level security;

create type public.feed_reference_comparison as (
  locality            text,
  fuel_type           text,
  previous_period_end date,
  new_period_end      date,
  previous_midpoint   numeric(6,2),
  new_midpoint        numeric(6,2),
  doe_movement        numeric(6,2),
  feed_movement       numeric(6,2),
  divergence          numeric(6,2)
);

create function public.compare_feed_to_reference()
returns setof public.feed_reference_comparison
language sql
stable
security definer
set search_path = ''
as $$
  with cells as (
    select r.doe_source_label as locality,
           p.fuel_type_code   as fuel_type,
           lr.period_end,
           ((p.min_price + p.max_price) / 2)::numeric(6,2) as midpoint,
           row_number() over (
             partition by r.doe_source_label, p.fuel_type_code
             order by lr.period_end desc) as recency
      from public.doe_reference_prices p
      join public.doe_locality_reports r on r.id = p.locality_report_id
      join public.doe_load_runs lr       on lr.id = r.run_id
     -- Only the locality-wide row, and only from a load that succeeded. A cell
     -- with a figure in just one period is skipped: a movement needs two.
     where p.brand_code = 'OVERALL'
       and p.brand_presence = 'reported'
       and lr.status = 'succeeded'
       and p.min_price is not null
       and p.max_price is not null
  )
  select
    cur.locality,
    cur.fuel_type,
    prev.period_end,
    cur.period_end,
    prev.midpoint,
    cur.midpoint,
    (cur.midpoint - prev.midpoint)::numeric(6,2),
    feed.total,
    abs((cur.midpoint - prev.midpoint) - feed.total)::numeric(6,2)
  from cells cur
  join cells prev
    on prev.locality = cur.locality
   and prev.fuel_type = cur.fuel_type
   and prev.recency = 2
  cross join lateral (
    -- The same interval convention the reference shift uses: an adjustment
    -- counts once it takes effect after the day the earlier period closed.
    select coalesce(sum(a.amount), 0)::numeric(6,2) as total
      from public.price_adjustments a
     where a.fuel_type_code = cur.fuel_type
       and a.effective_at >  ((prev.period_end + 1)::timestamp at time zone 'Asia/Manila')
       and a.effective_at <= ((cur.period_end  + 1)::timestamp at time zone 'Asia/Manila')
  ) feed
  where cur.recency = 1
  order by cur.locality, cur.fuel_type;
$$;

comment on function public.compare_feed_to_reference() is
  'Per-cell comparison of DOE midpoint movement against the sum of adjustments '
  'over the same interval. Read-only: a divergence is surfaced, never resolved.';

-- The median across cells, and whether it clears the threshold.
--
-- A median rather than per-cell alarms, and that is the whole design of this
-- check. A DOE midpoint moves for reasons unrelated to any adjustment: the set
-- of outlets surveyed changes between periods, and with ranges 8 to 21 pesos
-- wide a different sample shifts the midpoint by a peso on its own. Per-cell
-- comparison would be mostly noise. A systematic parsing error moves every cell
-- the same way, so it survives the median while sampling noise does not.
create view public.adjustment_feed_divergence as
select
  count(*)                                                        as cells_compared,
  percentile_cont(0.5) within group (order by c.divergence)       as median_divergence,
  max(c.divergence)                                               as worst_cell_divergence,
  (select s.divergence_threshold from public.adjustment_feed_settings s) as threshold,
  coalesce(
    percentile_cont(0.5) within group (order by c.divergence)
      > (select s.divergence_threshold from public.adjustment_feed_settings s),
    false)                                                        as exceeded
from public.compare_feed_to_reference() c;

comment on view public.adjustment_feed_divergence is
  'Median divergence between the feed and the reference across every comparable '
  'cell. exceeded = true means the feed, the parser, the category mapping, or '
  'the reference data is wrong; which one cannot be told from here.';

revoke all on function public.compare_feed_to_reference() from public;
grant execute on function public.compare_feed_to_reference() to service_role;
alter view public.adjustment_feed_divergence set (security_invoker = true);
