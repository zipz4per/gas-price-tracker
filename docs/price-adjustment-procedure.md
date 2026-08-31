# Price Adjustment Feed — Manual Run Procedure

Oil companies adjust prices most Tuesdays, announced the evening before and
effective at 6 a.m. DOE's own monitored figures for that week arrive days later,
so there is a window of roughly a week, every week, in which the true price is
public and the app does not have it. This is what closes it.

Nothing runs on a timer. Same as the DOE loader: you run it, and the run says
what it found.

```bash
python3 scripts/ingest-price-adjustments.py --dry-run   # read, report, write nothing
python3 scripts/ingest-price-adjustments.py             # read and record
python3 scripts/ingest-price-adjustments.py --linked    # against the hosted project
```

## 1. What it does

For each active source in `adjustment_sources` it reads the feed, extracts
candidate adjustments, and — where two independent sources agree — records one
adjustment per fuel grade the announced category covers. Every attempt is
recorded in `adjustment_load_runs`, including the ones that find nothing.

The extractor is deliberately simple. It finds a category, finds a number near
it, finds a direction word, and refuses when any of those is missing or
implausible. It does not understand language and is not meant to: two checks
stand behind it, and refusing is cheap while guessing moves every derived price
of a grade at once.

## 2. Read the run outcome

```sql
select outcome, adjustments_recorded, sources_reached, failure_reason, note
  from adjustment_load_runs order by seq desc limit 5;
```

| Outcome | What it means | What to do |
|---|---|---|
| `recorded` | Two independent sources agreed; adjustments written | Nothing |
| `none_announced` | Sources reached, no announcement found | Nothing. This is a quiet week |
| `corroboration_missing` | An announcement found, but only one witness | Usually nothing — see §3 |
| `conflict` | Witnesses disagreed on the amount | Settle it — see §4 |
| `failed` | The attempt did not complete | `failure_reason` says why. Nothing is known about this week |

**`none_announced` and `failed` are the pair that matters.** The first says a
derived price is still current; the second says nobody knows whether it is. A run
that reaches its sources and finds nothing is never recorded as a failure, and a
run that cannot reach them is never recorded as a quiet week.

```sql
select * from adjustment_feed_state;
```

`last_run_at` and `last_reached_sources_at` are equal while the feed is healthy
and diverge the moment it breaks. Only the second says whether the picture is
current.

## 3. Corroboration missing

One source carried the story and no other did, or two carried the same wire copy
and were folded into one witness. No adjustment is recorded, by design: a single
reading of anything is a single point of failure, and a wrong amount is invisible
from inside the system once applied.

This is common and usually needs no action. Investigate when it repeats for
weeks — that is what a source having quietly changed its feed format looks like
from here. Check `sources_reached` on recent runs.

## 4. Conflict

```sql
select c.source_code, c.amount, c.citation_span, c.article_url
  from adjustment_run_conflicts c
  join adjustment_load_runs r on r.id = c.run_id
 order by r.seq desc, c.source_code;
```

Two witnesses in different independence groups reported different amounts for
the same category and effective instant. No adjustment was written. The citation
spans are there so the disagreement can be settled by reading what each outlet
actually printed.

If one is right, record it by hand and note where it came from. If they are
reporting different companies' announcements — Seaoil and Shell often differ by a
few centavos — either is inside the error the carry-forward limit tolerates.

## 5. Unmapped category

The run note names a category phrasing with no mapping. Nothing was recorded for
it, and nothing was guessed at.

Add the phrasing if it means a category we already cover:

```sql
insert into adjustment_category_aliases (alias, category, note)
values ('premium gasoline', 'gasoline', 'seen in Philstar copy 2026-09-07');
```

Add the category itself only if the industry genuinely announces it separately.
Note that `gas` is deliberately not an alias: in Philippine coverage it means LPG
as often as gasoline, and a category matched wrongly applies a real adjustment to
the wrong grades.

## 6. Refused: ordered list

The run note says a window was refused because figures were not beside their
categories. This is the *respectively* construction:

> "larger cuts for diesel and kerosene, reaching P3.83 and P3.84 respectively"

Proximity reads that backwards, and corroboration cannot save it — a second
outlet running the same sentence is misread identically. So it is refused and
left to a person. Record the figures by hand if they matter.

## 7. Divergence from DOE

Run this after loading a new DOE reference period:

```sql
select * from adjustment_feed_health;
select * from adjustment_feed_divergence;   -- per fuel type
select * from compare_feed_to_reference();  -- per locality and fuel type
```

Between two DOE periods, the locality-wide midpoint should have moved by roughly
the sum of the adjustments announced over that interval. DOE is the only
independent measurement of the same quantity, and once adjustments drive
displayed prices it is the only thing that can notice a systematic misread —
everything else in the system is downstream of the same number.

`exceeded = true` means look. It does not say what is wrong: the feed, the
parser, the category mapping, and the reference data are all candidates, and the
divergence alone cannot tell them apart. Nothing is corrected automatically.

**How to read it.** The median is taken per fuel type across localities, because
the two failures have different shapes:

- a parser error — **one fuel type** diverging in every locality
- DOE survey noise — **one locality** diverging in every one of its fuel types

A fuel type reported in only one locality does not vote; its median is that
town's number and separates nothing.

**Known limit.** Two localities is not really enough either — a median over two
interpolates, so one noisy town still carries half the weight. Three or more is
where a town is outvoted. Coverage today is three localities across two DOE
regions and only one region has more than one loaded period, so this check
currently runs on two and will surface survey noise alongside parser error until
coverage grows.

The threshold lives in `adjustment_feed_settings.divergence_threshold`
(currently ₱1.00). At that value a one-tenth misread of a ₱1.20 announcement is
caught; a missed ₱1.00 adjustment sits exactly on the line.

## 8. Correcting an adjustment

```sql
select correct_price_adjustment(
  '<adjustment-id>', 'misread P1.20 as P0.12', 1.20);
```

Every price derived from it reflects the correction on the next read. There is
no backfill and no station to visit: derived prices are computed, not stored.

The previous amount, the previous effective instant, and the reason are kept in
`price_adjustment_revisions`, so a figure a driver saw yesterday can still be
explained. A correction without a reason is rejected, and so is one that changes
nothing.

## 9. If nothing is ever recorded

Expected at first. An adjustment needs two independent sources to carry the same
figure with the same effective instant, and the registry currently holds three
reachable outlets. A week where only one carries the story records
`corroboration_missing` and writes nothing — correctly.

If it persists, the questions in order are: are the feeds still reachable
(`sources_reached`), are announcements being found at all (the run note), and are
the effective dates being read (`UNDETERMINED` in `--dry-run` output). RSS
summaries are truncated and the effective date is usually in the part that is
cut, which is why the script fetches the linked article when the summary alone
cannot answer.
