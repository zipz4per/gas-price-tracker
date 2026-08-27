## 1. Lookup tables

- [x] 1.1 Create the `fuel_types` table with canonical codes and per-fuel-type plausibility bounds, seeded with RON 100, RON 97, RON 95, RON 91, Diesel, Diesel Plus, and Kerosene; verify Kerosene's upper bound exceeds ₱134 so observed real prices pass validation
- [x] 1.2 Create the `brands` table seeded with the union of brand columns across both reports (Petron, Shell, Caltex, Phoenix, Total, Unioil, Seaoil, Flying V, PTT, Independent) plus the reserved `OVERALL` sentinel; verify a query for an unseeded brand name returns no row

## 2. Load hierarchy tables

- [x] 2.1 Create the `doe_load_runs` table with status (`in_progress`/`succeeded`/`failed`), source URL, period start/end, and verbatim period label; verify a run cannot be created without a source URL and period dates
- [x] 2.2 Create the `doe_locality_reports` table with run reference, DOE source locality label, and status (`data`/`no_outlet`); verify the run + locality pair is unique
- [x] 2.3 Create the `doe_reference_prices` table with locality-report reference, fuel type, brand, and nullable min/max/common prices; verify a row with `min > max` is rejected and that all three price columns accept NULL
- [x] 2.4 Add indexes supporting lookup by locality label and fuel type scoped to the latest succeeded run, and verify they are used via `EXPLAIN`

## 3. Loader function

- [x] 3.1 Define the flat input row shape (locality label, fuel type, brand, min, max, common) as the loader's contract and verify a fixture file of Tanauan City rows parses into the expected row count
- [x] 3.2 Implement the loader to expand flat rows into run → locality report → price rows inside a single transaction, and verify a successful load produces exactly one `succeeded` run
- [x] 3.3 Enforce per-fuel-type plausibility bounds and `min ≤ max` in the loader, and verify a fixture containing an out-of-bounds gasoline price fails the whole run with no rows persisted
- [x] 3.4 Verify per-fuel-type bounds accept real kerosene data by loading a fixture with kerosene at ₱134 and confirming it is not rejected
- [x] 3.5 Normalize the four absent-value spellings (unavailable marker, literal `None`, `0.00`, `No LFRO`) so prices become NULL; record `No LFRO` against the **brand** it appears under, marking that brand as not operating in the locality, and set the locality report to `no_outlet` only when every brand is so marked; verify each spelling maps to its expected state, that a row mixing `No LFRO` brands with priced brands retains all its prices, and that none is stored as a price
- [x] 3.6 Fail a run when a registered locality expected in the document matches zero source rows, and verify the run is marked `failed` with an operator-reviewable reason while an explicit `no_outlet` locality does not fail
- [x] 3.7 Fail a run when a registry entry's normalized source label matches more than one distinct source label, and verify the ambiguity is reported rather than silently resolved
- [x] 3.8 Verify load atomicity: run a load that fails at the last row and confirm no run, locality report, or price row from it is persisted as visible

## 4. Access control

- [x] 4.1 Enable RLS on the lookup and load-hierarchy tables and verify that with RLS on and no policies, the anon role can read nothing
- [x] 4.2 Add `SELECT` policies for the anon and authenticated roles on those tables and verify anonymous reads succeed
- [x] 4.3 Verify no insert, update, or delete policy exists on any table created in this change by attempting each as the anon role and confirming all are rejected

## 5. Manual load procedure

- [x] 5.1 Write the operator procedure documenting where each report is found, how to read its table, which columns map to which fields, and how to produce the flat input file; verify a second person can follow it unaided for one locality
- [x] 5.2 Record the per-region differences the procedure must handle — period label wording and span, the four absent-value spellings, and the `Taguig Cty` source spelling — and verify the document covers all of them
- [x] 5.3 Record that naive PDF text extraction is unsafe for this data, with the reason (blank brand columns vanish, so field position cannot identify a brand), so a future implementer does not reach for it

## 6. First loads and verification

- [x] 6.1 Perform the first load from the CALABARZON report for Tanauan City and Lipa City against the local stack, and verify both localities have stored rows for RON 95 and Diesel
- [x] 6.2 Perform the first load from the NCR report for Taguig against the local stack, and verify rows are stored under the `Taguig Cty` source label
- [x] 6.3 Verify the two loads produce different period spans (3-day for CALABARZON, 7-day for NCR) and that neither is widened or relabelled
- [x] 6.4 Verify the no-destroy guarantee: after a successful load, attempt a failing load for the same locality and confirm the original period's rows are intact and still the latest succeeded
- [x] 6.5 Verify every scenario in `specs/doe-reference-prices/spec.md` against the deployed schema and record any that cannot be exercised
