-- Aggregate the cross-check by FUEL TYPE across localities, not across all
-- cells at once.
--
-- The first version took one median over every comparable cell, on the reasoning
-- that a systematic parsing error moves every cell together while sampling noise
-- moves one. The second half of that is wrong, and testing showed it: DOE
-- sampling noise is a property of a LOCALITY - the set of outlets surveyed in a
-- town changes between periods - so it moves every cell of that town at once.
-- With three localities, one noisy town is a third of the cells, and a single
-- town's survey churn raised the alarm on its own.
--
-- The two failures have different shapes, and aggregating along the right axis
-- separates them:
--
--   a parser error   one fuel type wrong in EVERY locality
--   sampling noise   one locality wrong in EVERY fuel type
--
-- So the median is taken per fuel type across localities. A misread gasoline
-- figure survives it, because every locality agrees gasoline moved differently
-- than the feed says. A town whose survey changed is outvoted by the others.

drop view public.adjustment_feed_divergence;

create view public.adjustment_feed_divergence as
select
  c.fuel_type,
  count(*)                                                  as localities_compared,
  percentile_cont(0.5) within group (order by c.divergence)  as median_divergence,
  min(c.divergence)                                          as best_locality,
  max(c.divergence)                                          as worst_locality,
  min(c.previous_period_end)                                 as previous_period_end,
  max(c.new_period_end)                                      as new_period_end
from public.compare_feed_to_reference() c
group by c.fuel_type;

comment on view public.adjustment_feed_divergence is
  'Divergence between the feed and the reference, median across localities for '
  'each fuel type. A parser error shows as one fuel type diverging in every '
  'locality; a town whose DOE sample changed is outvoted.';

create view public.adjustment_feed_health as
select
  (select count(*) from public.adjustment_feed_divergence)         as fuel_types_compared,
  (select max(d.median_divergence) from public.adjustment_feed_divergence d)
                                                                    as worst_fuel_median,
  (select d.fuel_type from public.adjustment_feed_divergence d
    order by d.median_divergence desc nulls last limit 1)           as worst_fuel_type,
  (select s.divergence_threshold from public.adjustment_feed_settings s) as threshold,
  coalesce(
    (select max(d.median_divergence) from public.adjustment_feed_divergence d)
      > (select s.divergence_threshold from public.adjustment_feed_settings s),
    false)                                                          as exceeded;

comment on view public.adjustment_feed_health is
  'One row. exceeded = true means at least one fuel type diverges from the '
  'reference in most localities, which is the shape of a parsing or mapping '
  'error rather than of survey noise. Which of them it is cannot be told here.';

alter view public.adjustment_feed_divergence set (security_invoker = true);
alter view public.adjustment_feed_health     set (security_invoker = true);
