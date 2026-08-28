## 1. Recognition in the read path

- [x] 1.1 Resolve the requested fuel type to a registered code through `normalize_locality_label()`, and verify `RON 95`, `ron_95`, and `RON_95` all return the same seven Malvar rows
- [x] 1.2 Raise on a fuel type that normalizes to no registered code, and verify `BANANA` raises rather than returning a `has_data = false` row
- [x] 1.3 Raise on a locality that normalizes to no registered locality, and verify `Atlantis` raises rather than returning an empty set
- [x] 1.4 Name the failing argument and the registered values in each error, and verify the fuel-type message lists all seven codes and the locality message lists the three registered localities
- [x] 1.5 Verify both errors surface through PostgREST as a client error distinguishable from a server fault
- [x] 1.6 Return the registered code rather than the requested spelling, and verify a request for `RON 95` yields rows whose `fuel_type` reads `RON_95`

## 2. Absence is untouched

- [x] 2.1 Verify a registered locality with a registered fuel type and no figures still returns the single `has_data = false` row, carrying the reporting period
- [x] 2.2 Verify a registered locality with no succeeded run at all still returns the single `has_data = false` row
- [x] 2.3 Verify proxy attribution, run-gated visibility, and absent-brand semantics are unchanged, by re-running every scenario in `openspec/specs/doe-reference-prices/spec.md` that passed before this change
- [x] 2.4 Verify the anon role can still call the function and that no write path became reachable through it

## 3. Close the bug

- [x] 3.1 Re-run the five-input reproduction from `openspec/bugs/doe-fuel-type-not-recognised/report.md` and record the new result for each
- [x] 3.2 Fill in that report's `Fixed by` and `What the fix changed`, naming the scenario that would now catch a regression
- [x] 3.3 Verify the report's `Does this need a change?` answer matches what was actually done, and correct it if the shape of the fix diverged from it

## 4. End-to-end verification

- [x] 4.1 Verify every scenario in `specs/doe-reference-prices/spec.md` for this change against the local stack, and record any that cannot be exercised
- [x] 4.2 Push the migration to hosted, verify no schema drift, and verify an anonymous call there rejects an unrecognised fuel type the same way
- [x] 4.3 Verify the `locality-registry` scenario "Unregistered locality is not covered" is now met by the read path, since it was the requirement this half discharges
