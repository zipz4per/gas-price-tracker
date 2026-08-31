## Why

`add-price-reports` defines what a price adjustment does — it shifts a station's last observation forward, it shifts the locality reference range, and it advances the counter that eventually retires a derived price. Nothing produces one. Until something does, the carry-forward mechanism has no input, every observation ages out on the 35-day clock alone, and the app is structurally a cycle behind whenever prices move.

That gap is worst at the moment the app matters most. Philippine oil companies adjust prices most Tuesdays, announced the evening before, effective at 6:00 in the morning. DOE's own monitored figures for that week arrive days later — the current load is 7 to 11 days behind today. So there is a window of roughly a week, every week, in which the true price is known publicly and the app does not have it.

The announcements themselves are public, factual, and specific: a signed amount per litre, per fuel category, with a stated effective time. Reading them is what closes the window.

This also decides something the earlier changes left implicit. Once adjustments drive the displayed price, the app becomes a closed loop — an observation plus a series of deltas — and a parser that misreads ₱1.20 as ₱0.12 moves every price together with nothing inside the system able to notice. This change therefore ships its own check rather than assuming correctness.

## What Changes

- **Introduce a price adjustment as a recorded fact** — a signed per-litre amount, for a set of fuel types, effective at a stated time, attributed to the sources that reported it.
- **Ingest adjustments from published announcements**, recording the source of each and the time it was read.
- **Require agreement before an adjustment is accepted.** A single outlet's figure is not sufficient. Two independent sources reporting the same amount for the same fuel category and effective time make an adjustment; sources that disagree produce no adjustment and a recorded conflict, because a wrong delta moves every price in the app at once.
- **Expand an announced fuel category to the canonical fuel types it covers** through a maintained mapping. Announcements speak of "gasoline", "diesel", and "kerosene"; the system stores seven grades, and which grades a category covers is data rather than a rule buried in a parser.
- **Record every ingestion attempt, including the ones that find nothing.** "No adjustment was announced this week" and "we failed to find out" are different facts with opposite consequences, and only the second should widen the tolerance on a stale price.
- **Require an explicit effective time from the announcement** rather than assuming the next Tuesday. The weekly cycle is a convention, not a guarantee; off-cycle adjustments happen, and an assumed effective time would silently misdate them.
- **Cross-check the feed against DOE.** When a new DOE report is loaded, the movement in its locality-wide midpoint since the previous report SHALL be compared against the sum of adjustments ingested over the same period. This is the only independent measurement of the same quantity, and it works from the first week with no crowdsourced data at all.
- **Make an adjustment correctable.** A published figure can be wrong or revised. Because derived prices are computed on read, correcting an adjustment repairs every price that descends from it; the correction path exists so nobody edits a row by hand.

### Explicitly out of scope

- **Scheduling.** This change establishes ingestion and its run records; running it on a timer is a separate concern, and the DOE loader's manual procedure is the established pattern to follow first.
- **Any change to how adjustments are applied.** `add-price-reports` owns the effect; this change owns the fact.
- **Per-brand and per-region adjustments.** Announcements are national and applied nationally. Brands occasionally differ by a few centavos and regions by freight; both are inside the error the carry-forward limit already accounts for.
- **Republishing article text.** The system extracts a figure and records where it came from. No source's prose is stored or displayed.
- **Backfilling historical adjustments.** The feed starts from its first successful run.

## Capabilities

### New Capabilities

- `price-adjustments`: What a price adjustment is, what evidence establishes one, how an announced fuel category maps to canonical grades, how an ingestion run reports what it did and did not find, and how the feed is checked against an independent source.

### Modified Capabilities

None. `price-reports` already specifies what an adjustment does to an observation and to a reference range; this change supplies the adjustments and does not alter their effect. `doe-reference-prices` is read by the cross-check and keeps its requirements unchanged.

## Impact

- **New:** an ingestion path over published announcements, and `adjustment_load_runs` recording each attempt, what it read, and whether it found an adjustment, a conflict, or nothing.
- **New:** a maintained mapping from announced fuel categories to canonical fuel types.
- **New:** a comparison between feed-derived movement and DOE-observed movement, surfaced when they diverge beyond a threshold.
- **Populates:** `price_adjustments`, introduced by `add-price-reports` and currently written by nothing.
- **New dependency:** published price announcements as an external source, with the availability and parsing risks that implies — recorded here rather than discovered in production.
- **Depends on:** `add-price-reports` for the `price_adjustments` table and for the fuel types adjustments apply to; `doe-reference-prices` for the cross-check.
- **Unblocks:** the carry-forward mechanism, which until now has a defined effect and no cause.
