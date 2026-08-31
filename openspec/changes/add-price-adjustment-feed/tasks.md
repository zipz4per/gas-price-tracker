## 1. Source registry and category mapping

- [ ] 1.1 Create `adjustment_sources` — name, feed URL, independence group, active flag — with RLS and read grants; verify two rows sharing an independence group are retrievable as one group, since that is the comparison corroboration depends on
- [ ] 1.2 Seed the registry with the outlets to be consulted, assigning independence groups so that syndicated republication shares a group with its originator; verify no two seeded sources share a group unless they are known to share copy
- [ ] 1.3 Create `adjustment_category_fuel_types` mapping an announced category to canonical fuel types, constrained to `fuel_types(code)`; verify an entry naming an unregistered grade is rejected
- [ ] 1.4 Seed the mapping for gasoline, diesel, and kerosene; verify gasoline expands to the RON grades the industry adjusts together and that every registered fuel type is either covered or deliberately absent

## 2. Run records

- [ ] 2.1 Create `adjustment_load_runs` with an outcome enum covering recorded, none announced, corroboration missing, conflict, and failed, plus the sources consulted and a failure reason required when the outcome is failed; verify a failed run without a reason is rejected by a check constraint
- [ ] 2.2 Create conflict detail rows naming each source and the amount it reported; verify a conflict run stores one row per disagreeing source
- [ ] 2.3 Expose the most recent run that reached its sources, distinguishable from the most recent run of any kind; verify a failed run following a successful one does not advance the successful-run timestamp
- [ ] 2.4 Verify a run that reaches its sources and finds nothing records "none announced" and not "failed", by running against a period with no announcement

## 3. Extraction

- [ ] 3.1 Implement candidate extraction over each source's feed, capturing the source, publication time, extracted category, signed amount, and the short citation span the numbers were read from; verify a rollback yields a negative amount and no separate direction field
- [ ] 3.2 Resolve a relative effective day against the announcement's publication time in `Asia/Manila`, and reject a resolved instant more than a few days from publication as unparsed; verify "effective 6 a.m. Tuesday" published on a Monday resolves to the following day, and that an unbounded resolution is rejected rather than accepted
- [ ] 3.3 Produce no adjustment and surface the announcement where no effective instant can be determined; verify an announcement with no stated effective time is surfaced rather than defaulted onto the weekly cycle
- [ ] 3.4 Surface an announced category with no mapping rather than guessing at the grades it covers; verify an unmapped category records nothing and appears for review with its announcement

## 4. Corroboration

- [ ] 4.1 Require two sources in different independence groups reporting the same amount, category, and effective instant before recording an adjustment; verify a single source records "corroboration missing" and no adjustment
- [ ] 4.2 Record a conflict and no adjustment where sources in different groups report different amounts; verify both figures and both sources are retained
- [ ] 4.3 Treat two candidates with near-identical citation spans as one source; verify two feeds carrying the same wire copy do not corroborate each other
- [ ] 4.4 Expand a corroborated category into one adjustment per covered fuel type, each with the same amount and effective instant; verify a gasoline adjustment writes one row per covered RON grade
- [ ] 4.5 Verify the unique constraint on `(fuel_type_code, effective_at)` rejects a re-run of the same announcement, so a second ingestion of one adjustment cannot double every derived price

## 5. Corrections

- [ ] 5.1 Create `price_adjustment_revisions` retaining the superseded amount, effective instant, and the reason for the change; verify a correction leaves the previous values readable
- [ ] 5.2 Implement the correction path so the live row is updated and revisions accumulate; verify a station's derived price reflects a corrected amount immediately, with no backfill and no per-station intervention
- [ ] 5.3 Verify a correction to an adjustment that no derived price descends from succeeds and changes nothing observable

## 6. DOE cross-check

- [ ] 6.1 Implement the comparison — for each locality and fuel type with an `OVERALL` row in both the new and previous period, the movement in the midpoint against the sum of adjustments effective between the two period ends; verify it runs over the cells that currently have `OVERALL` data and skips the rest
- [ ] 6.2 Report the median divergence across cells rather than per-cell alarms, with the threshold in settings starting at ₱1.50; verify a single noisy cell does not raise a divergence while a uniform shift across all cells does
- [ ] 6.3 Surface a divergence beyond the threshold with both measurements and the interval compared, altering nothing; verify neither an adjustment nor a reference figure is modified by the check
- [ ] 6.4 Verify the check catches an order-of-magnitude error by ingesting an adjustment at one tenth of its announced amount and confirming the following period's comparison exceeds the threshold
- [ ] 6.5 Verify the check catches a missed adjustment — the case with no conflict and no failure — by omitting one and confirming the reference movement diverges from the feed's silence

## 7. Documentation

- [ ] 7.1 Write the manual run procedure alongside `docs/doe-manual-load-procedure.md`, covering how to run ingestion, how to read each run outcome, and what to do with a conflict, an unmapped category, and a divergence; verify a reader can distinguish a quiet week from a failed check from the run records alone
- [ ] 7.2 Document the source registry as a maintained surface — how to add an outlet and how to assign its independence group — and record that corroboration is only as good as those groups; verify the document states what happens if two sources sharing copy are placed in different groups
