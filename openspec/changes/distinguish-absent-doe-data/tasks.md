# Tasks

## 1. Establish the four cases before changing anything

- [x] 1.1 Confirm all four absence cases are currently reported identically, by
      producing each against a scratch database and capturing the result.
- [x] 1.2 Confirm `doe_load_runs` and `doe_locality_reports` already carry enough
      to tell A from B, so no table is needed.
- [x] 1.3 Confirm the false sentence is composed inside
      `get_stations_with_reference_prices()` and not by any caller.
- [x] 1.4 Record anything that contradicts the design in `design.md`.

## 2. The reason

- [x] 2.1 Add the absence-reason enum with the four values.
- [x] 2.2 Resolve it in escalation order, stopping at the first that holds.
- [x] 2.3 Verify A is reported when no run has ever succeeded.
- [x] 2.4 Verify B is reported when succeeded runs exist but none covers the
      locality, and that the result names no brand.
- [x] 2.5 Verify C is reported when the locality was reported and the fuel type
      was not.
- [x] 2.6 Verify a brand carrying no figure in a report that did cover the
      locality and fuel type still has no row, and that the result reports no
      reason describing the locality or fuel type as absent. Case D belongs to
      the station path — see the decision in `design.md`.
- [x] 2.7 Verify a failed run does not count as ingestion for case A.
- [x] 2.8 Verify the reason is null when `has_data` is true, and non-null
      whenever it is false — a no-data row without a reason must be
      unrepresentable.

## 3. The station path

- [x] 3.1 Take the reason as input and compose the station's sentence from it.
- [x] 3.2 Verify a station whose brand DOE did not monitor still says the source
      published no figures for that brand.
- [x] 3.3 Verify that with nothing ingested, every station says so and none
      blames the source.
- [x] 3.4 Verify a station with no resolved brand says its brand is not yet
      identified, and does not blame the source.
- [x] 3.5 Verify every station is still returned in all four cases.
- [x] 3.6 Verify no sentence names a locality by its verbatim DOE source label,
      which is kept because it contains errors.

## 4. Seeding

- [x] 4.1 Write a script that generates `supabase/seed.sql` from
      `doe_load_runs`, `doe_locality_reports` and `doe_reference_prices`.
- [x] 4.2 Generate the seed from the current hosted data and commit it.
- [x] 4.3 Verify `supabase db reset` restores the DOE rows, by counting before
      and after.
- [x] 4.4 Verify the restored data produces the same read-path results as before
      the reset, rather than merely the same row count.
- [x] 4.5 Note in `docs/doe-manual-load-procedure.md` that a load is followed by
      regenerating the seed, and that a reset without one loses the data.

## 5. End to end

- [x] 5.1 Verify every scenario in both delta specs against the local stack.
- [x] 5.2 Verify the bug's own reproduction table now produces the expected
      column rather than the actual one.
- [x] 5.3 Push to hosted, verify no drift, and verify an anonymous read returns
      the reason.
- [x] 5.4 Update `openspec/bugs/doe-data-lost-on-db-reset/report.md`: root cause,
      fixed by, what the fix changed, and the change question.
- [x] 5.5 `openspec validate --strict` passes.
