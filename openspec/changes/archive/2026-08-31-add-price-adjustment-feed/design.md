## Context

See `proposal.md` — Why, and `specs/price-adjustments/spec.md` for the behaviour required.

What already exists and constrains this:

- **`price_adjustments` is defined and unwritten.** `add-price-reports` creates it, keyed unique on `(fuel_type_code, effective_at)`, and computes derived prices from it on read. This change is its only writer.
- **Derived prices are computed, not materialized.** A corrected adjustment therefore repairs every price descending from it with no backfill, which is why the correction path in the spec is cheap to provide.
- **The project's loaders are Python scripts run by hand**, with a documented procedure — `docs/doe-manual-load-procedure.md`, `scripts/import-stations.py`. This one follows that pattern rather than introducing scheduling.
- **`doe_load_runs` already models "an attempt, its outcome, and its failure reason"**, including the distinction between a failed load and an empty one. The run records here are the same idea applied to a different source.

## Goals / Non-Goals

**Goals:**

- An ingestion path whose correctness does not depend on parsing being clever.
- A record of every attempt sufficient to answer "is the displayed price current, or do we merely not know?"
- A check that would catch a systematically misread amount without any crowdsourced data.

**Non-Goals:**

- Scheduling, retries, and alerting. The 35-day carry-forward backstop in `add-price-reports` is what covers a run nobody remembers to make.
- Natural-language understanding. See the parser decision below.
- Storing or displaying any source's prose.

## Decisions

### Build a weak parser and two strong checks, rather than a strong parser

Announcement phrasing varies across outlets — "up by ₱1.20 per liter", "a rollback of ₱0.50", "hike of P1.20/L" — and a rule-based extractor over that will misread some fraction of them. The design accepts that instead of trying to engineer it away, because two independent checks stand behind it:

```
  extract  ──▶  corroboration     two sources must agree on the amount
           ──▶  DOE cross-check   the next reference report must move by
                                  roughly the sum of what was ingested
```

A misread amount fails the first check unless two outlets are misread identically, and fails the second within a week even then. **The alternative — a language model in the ingestion path — adds a dependency, a cost, and a failure mode to a project that currently has none of the three**, to improve a step that is already double-checked. Revisit if the checks prove to reject too much, not before.

### Independence means editorially independent, not different URLs

Corroboration is worthless if both sources are the same copy. Philippine outlets frequently run identical wire copy, so two feeds can carry one story under two mastheads and look like agreement.

Sources are therefore an explicit registry with an independence group, and two sources corroborate only when their groups differ. Syndicated republication sits in the same group as its originator.

A secondary guard: where two candidate reports share a near-identical extracted context string, the run records them as one source rather than two.

### An oil company's own announcement is a source, not an authority

It is tempting to treat a company's own statement as sufficient on its own. It is not treated that way here — partly because a single reading of anything is a single point of failure regardless of who published it, and partly because the app applies one national delta to every brand, so what matters is the industry-wide movement rather than one company's. Two companies announcing the same amount is corroboration under the same rule as two newspapers.

### Store the extracted figure and a short citation span, not the article

Each candidate record keeps the source URL, the publication time, the extracted values, and **the span of text the numbers were read from** — a phrase, not a paragraph.

**Why keep any text at all**, given the proposal excludes republishing prose. Because a parse that goes wrong is otherwise undebuggable: a number with no context cannot be checked against what was actually written without re-fetching an article that may have changed or gone. A short citation span is the minimum that makes a wrong figure explicable, and it is a fact citation rather than a reproduction. It is not displayed to users.

### Resolve relative effective dates against publication time, then bound the result

Announcements say "effective 6 a.m. Tuesday", not a date. The extractor resolves the day name against the announcement's publication timestamp and takes the next such day, in `Asia/Manila`.

The result is then bounded: an effective instant more than a few days from publication is treated as unparsed rather than accepted. This is what stops a relative-date resolution from quietly landing an adjustment in the wrong week — the spec forbids assuming the cycle, and an unbounded relative resolution is that assumption wearing a different hat.

### The DOE cross-check compares medians across cells, with a generous threshold

For each locality and fuel type that has an `OVERALL` row in both the newly loaded period and the previously loaded one:

```
  doe_movement   = midpoint(new period) − midpoint(previous period)
  feed_movement  = Σ adjustments effective between the two period ends
  divergence     = median over cells of |doe_movement − feed_movement|
```

**Why a median across cells rather than a per-cell alarm.** A DOE midpoint moves for reasons unrelated to any adjustment: the set of outlets surveyed changes between periods, and with ranges ₱8–21 wide a different sample shifts the midpoint by a peso without any price having moved. Per-cell comparison would be mostly noise. Taking the median across the eight cells that currently have `OVERALL` data suppresses sample noise while leaving a systematic parsing error — which moves every cell the same way — fully visible.

The threshold starts at ₱1.50 and is configuration. It is set to catch order-of-magnitude and sign errors, which is the failure class that matters; a ₱0.20 misread is inside the error the carry-forward limit already tolerates.

### Corrections are a new row plus a supersession, not an update in place

`price_adjustment_revisions` retains the previous amount, effective instant, and the reason for the change. The live row is updated so that derived prices — computed on read — pick the correction up immediately.

Editing in place without history would make a price a user saw yesterday unexplainable, which matters more here than in most tables: the whole ladder is built on being able to say what a figure is and where it came from.

### Category expansion is a table, not a rule in the extractor

`adjustment_category_fuel_types` maps an announced category to the canonical grades it covers. Gasoline covering four RON grades is a fact about the industry that changes independently of any code, and burying it in a parser is how it becomes undiscoverable when it changes.

An unmapped category surfaces for review rather than defaulting, on the same reasoning that governs unresolved brand names in the station registry.

## Risks / Trade-offs

- **Syndication defeats corroboration.** Two mastheads, one wire story, apparent agreement. → Independence groups in the source registry, plus the near-identical-span guard. Both are heuristics; neither is proof, and the DOE cross-check remains the backstop.

- **The parser misses an adjustment entirely.** A missed hike is invisible: no conflict, no failure, just a quiet week that was not quiet. → The DOE cross-check catches it in the following period, because the reference will have moved when the feed says nothing did. This is the strongest argument for the cross-check being part of this change rather than a later addition.

- **Nobody runs the ingestion.** With no scheduling, the feed goes silent exactly as if it had failed. → The 35-day carry-forward backstop ages observations out regardless. The run records make the silence visible to anyone who looks; nothing makes anyone look.

- **DOE sample composition moves the midpoint on its own.** → Median across cells and a threshold set for order-of-magnitude errors. Accepted that small parsing errors pass this check.

- **Two adjustments in one week, or an intra-week correction.** Uniqueness is on fuel type and effective instant, so both are representable; the risk is the extractor collapsing them. → Effective instants are extracted per announcement, never per run.

- **A source disappears or changes format.** Feeds are reorganized without notice. → Failure is recorded as failure rather than as an empty result, which is the only property that makes the difference detectable at all.

## Migration Plan

1. `adjustment_sources` — the registry, with independence groups.
2. `adjustment_category_fuel_types` — the category expansion mapping, seeded for gasoline, diesel, and kerosene.
3. `adjustment_load_runs` with an outcome enum covering recorded, none announced, corroboration missing, conflict, and failed; plus conflict detail rows.
4. `price_adjustment_revisions` and the correction path.
5. The ingestion script, following the shape of the existing loaders.
6. The DOE cross-check, run when a reference period is loaded, with its threshold in settings.
7. A manual run procedure alongside `docs/doe-manual-load-procedure.md`.

Every step is additive; `price_adjustments` gains its first writer and no existing behaviour changes. Rollback is ceasing to run the ingestion — derived prices fall back through the carry-forward limit on their own.

## Open Questions

- **The divergence threshold's value.** ₱1.50 is a starting point; a few periods of observed DOE midpoint noise will settle it without touching the specs.
- **Whether to keep candidate records for announcements that produced no adjustment.** Useful for tuning the extractor, and a retention question rather than a behavioural one.
