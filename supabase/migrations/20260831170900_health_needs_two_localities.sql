-- A fuel type compared in one locality cannot vote.
--
-- The health verdict rests on agreement between localities: a parser error is
-- one fuel type diverging in all of them, and a town whose DOE sample changed is
-- one locality diverging in all of ITS fuel types. A fuel type that exists in a
-- single locality's report offers neither pattern - its median IS that town's
-- number - so including it in the verdict turns local survey churn into a feed
-- alarm. Kerosene is exactly this today: reported in Lipa City and nowhere else.
--
-- Such fuels stay visible in adjustment_feed_divergence, because a person
-- reading the detail should still see them. They are excluded from `exceeded`.
--
-- KNOWN LIMIT, recorded rather than papered over. Two localities is not enough
-- either: with two, a median interpolates between them, so one noisy town still
-- carries half the weight and can raise the alarm on its own. Three or more is
-- where a single town is genuinely outvoted. Coverage today is three localities
-- across two DOE regions, and only one region has more than one loaded period,
-- so in practice this check currently runs on two. It will therefore surface
-- survey noise as well as parser error until coverage grows - which is the
-- failure direction to prefer, and the design already says a divergence is
-- surfaced for a person to interpret rather than resolved automatically.

drop view public.adjustment_feed_health;

create view public.adjustment_feed_health as
select
  (select count(*) from public.adjustment_feed_divergence)          as fuel_types_compared,
  (select count(*) from public.adjustment_feed_divergence d
    where d.localities_compared >= 2)                                as fuel_types_voting,
  (select max(d.median_divergence) from public.adjustment_feed_divergence d
    where d.localities_compared >= 2)                                as worst_fuel_median,
  (select d.fuel_type from public.adjustment_feed_divergence d
    where d.localities_compared >= 2
    order by d.median_divergence desc nulls last limit 1)            as worst_fuel_type,
  (select s.divergence_threshold from public.adjustment_feed_settings s) as threshold,
  coalesce(
    (select max(d.median_divergence) from public.adjustment_feed_divergence d
      where d.localities_compared >= 2)
      > (select s.divergence_threshold from public.adjustment_feed_settings s),
    false)                                                           as exceeded;

comment on view public.adjustment_feed_health is
  'One row. Only fuel types compared in two or more localities vote: a fuel '
  'reported in one town cannot separate a parser error from that town''s survey '
  'churn. exceeded = true is a signal to look, not a diagnosis.';

alter view public.adjustment_feed_health set (security_invoker = true);
