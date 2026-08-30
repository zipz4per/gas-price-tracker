# Tasks

## 1. Establish the four cases before changing anything

- [ ] 1.1 Confirm all four absence cases are currently reported identically, by
      producing each against a scratch database and capturing the result.
- [ ] 1.2 Confirm `doe_load_runs` and `doe_locality_reports` already carry enough
      to tell A from B, so no table is needed.
- [ ] 1.3 Confirm the false sentence is composed inside
      `get_stations_with_reference_prices()` and not by any caller.
- [ ] 1.4 Record anything that contradicts the design in `design.md`.

## 2. The reason

- [ ] 2.1 Add the absence-reason enum with the four values.
- [ ] 2.2 Resolve it in escalation order, stopping at the first that holds.
- [ ] 2.3 Verify A is reported when no run has ever succeeded.
- [ ] 2.4 Verify B is reported when succeeded runs exist but none covers the
      locality, and that the result names no brand.
- [ ] 2.5 Verify C is reported when the locality was reported and the fuel type
      was not.
- [ ] 2.6 Verify D is reported for a brand carrying no figure in a report that
      did cover the locality and fuel type.
- [ ] 2.7 Verify a failed run does not count as ingestion for case A.
- [ ] 2.8 Verify the reason is null when `has_data` is true, and non-null
      whenever it is false — a no-data row without a reason must be
      unrepresentable.

## 3. The station path

- [ ] 3.1 Take the reason as input and compose the station's sentence from it.
- [ ] 3.2 Verify a station whose brand DOE did not monitor still says the source
      published no figures for that brand.
- [ ] 3.3 Verify that with nothing ingested, every station says so and none
      blames the source.
- [ ] 3.4 Verify a station with no resolved brand says its brand is not yet
      identified, and does not blame the source.
- [ ] 3.5 Verify every station is still returned in all four cases.
- [ ] 3.6 Verify no sentence names a locality by its verbatim DOE source label,
      which is kept because it contains errors.

## 4. Seeding

- [ ] 4.1 Write a script that generates `supabase/seed.sql` from
      `doe_load_runs`, `doe_locality_reports` and `doe_reference_prices`.
- [ ] 4.2 Generate the seed from the current hosted data and commit it.
- [ ] 4.3 Verify `supabase db reset` restores the DOE rows, by counting before
      and after.
- [ ] 4.4 Verify the restored data produces the same read-path results as before
      the reset, rather than merely the same row count.
- [ ] 4.5 Note in `docs/doe-manual-load-procedure.md` that a load is followed by
      regenerating the seed, and that a reset without one loses the data.

## 5. End to end

- [ ] 5.1 Verify every scenario in both delta specs against the local stack.
- [ ] 5.2 Verify the bug's own reproduction table now produces the expected
      column rather than the actual one.
- [ ] 5.3 Push to hosted, verify no drift, and verify an anonymous read returns
      the reason.
- [ ] 5.4 Update `openspec/bugs/doe-data-lost-on-db-reset/report.md`: root cause,
      fixed by, what the fix changed, and the change question.
- [ ] 5.5 `openspec validate --strict` passes.
