# A local `supabase db reset` destroys the DOE reference data with nothing to restore it from

## What's broken

DOE reference prices are loaded by hand, by a person reading a PDF and calling
`load_doe_reference_prices()` with a JSON payload they typed. That payload is
never saved anywhere. `supabase db reset` re-runs the migrations and drops
everything they did not create, so the DOE rows vanish — and the only way back is
to find the same PDF and read the same table again.

Nothing warns about this. `docs/doe-manual-load-procedure.md` explains how to
load the data across seven sections and never mentions that a routine local
command deletes it. There is no `supabase/seed.sql`, and the payload was not
committed with the migration that introduced the loader.

## Impact

Local development only — hosted is unaffected, and hosted still held all 31 rows
when this was found, which is the reason nothing was permanently lost.

The blast radius is wider than the data. Every read path that depends on DOE
figures reports *the absence of a price* rather than an error when the table is
empty, because absence is a state this system deliberately models as legitimate.
So after a reset the app is not visibly broken: `get_doe_reference_prices()`
returns a well-formed `has_data = false` row and
`get_stations_with_reference_prices()` returns every station with
`has_reference_data = false` and the sentence *"No reference price: DOE does not
report Petron for RON_95 in Taguig City."*

That sentence is false, and it is indistinguishable from the true one. This
report exists because it was believed during verification of
`add-station-registry`: an entire locality reading "DOE does not report this
brand" was recorded as correct behaviour before the empty table was noticed.

## Reproduction

```
  input                                actual                    expected
  ────────────────────────────────────────────────────────────────────────────
  select count(*) from                 31                        31
    doe_reference_prices

  supabase db reset --local            "Reset local database."   (a warning that
                                                                 hand-loaded data
                                                                 will be dropped)

  select count(*) from                 0                         0
    doe_reference_prices

  get_stations_with_reference_prices   "No reference price:      an empty or
    ('Taguig City','RON_95')            DOE does not report      unavailable
                                        Petron for RON_95        reference state,
                                        in Taguig City."         distinguishable
                                                                 from a real
                                                                 no-report answer
```

## Root cause

Two decisions that are each correct alone.

DOE data is loaded manually rather than by migration, which is right: it is
observed data read off a published document, not schema, and
`docs/doe-manual-load-procedure.md` argues the case well. But manual loading
means the data exists only in the database, and `supabase db reset` is defined
to discard exactly that.

And absence is a first-class, blessed state. `20260828100000_create_reference_price_read.sql`
says so directly — *"Absent-brand semantics. A brand with no published price has
no row; inventing a zero would be a lie about the price of fuel"* — and
`fix-unrecognised-read-inputs` deliberately preserved it while adding recognition
for unknown inputs. That is the right model for a brand DOE did not monitor.

Together they produce a system where *no data loaded at all* is reported in the
same words as *this brand was not monitored*. The read path cannot tell the two
apart, because nothing records that a load was ever expected.

## Caused by

`d0a5676  Add DOE reference price storage and manual load procedure`  (never worked)

The manual load procedure shipped without a way to replay a load, and without a
warning that a reset discards one.

## Fixed by

`distinguish-absent-doe-data`

## What the fix changed

Absence now carries a reason, and the reason is the true one.

`get_doe_reference_prices()` reports which of three cases holds whenever
`has_data` is false — `no_data_ingested`, `locality_not_covered`,
`fuel_type_not_reported` — checked most-general-first, because they nest. The
enum is null exactly when there is data, so a no-data row without a reason is
not representable.

`get_stations_with_reference_prices()` composes its sentence from that reason
rather than from the single explanation it used to have, and adds the two cases
only it can see: `brand_not_reported` and `brand_not_identified`. On an empty
database all 34 Taguig City stations now say *"No reference price: no DOE
reference data has been ingested yet"* instead of blaming DOE for 34 brands it
reports perfectly well.

The scenario that would have caught this now exists in both capabilities:
*"Nothing ingested is distinct from nothing reported"* in `doe-reference-prices`,
and *"A station is not told the source is silent when nothing was ingested"* in
`station-registry`. Neither could have been satisfied by the old code.

The data-loss half is closed separately and more simply than expected.
`supabase/seed.sql` is generated from the recorded runs by
`scripts/generate-doe-seed.py` and committed, and `[db.seed] enabled = true` was
already in `config.toml` — so a reset now restores the load rather than
destroying it. Verified by fingerprinting the read path across every locality and
fuel type before and after a reset: identical, not merely the same row count.

## Does this need a change?

**Yes, added requirement** — `distinguish-absent-doe-data`.

The spec was silent rather than wrong. `doe-reference-prices` requires that
absence be an explicit state, and it is; `station-registry` requires that a
station's absent reference not be a zero or a blank, and it is not. Neither says
anything about whether the *stated reason* for the absence must be the true one,
so the implementation chose, and it chose the most specific of four possible
explanations.

The obligation is added by extending those two existing requirements rather than
by writing standalone ones, because "absence is explicit" and "absence says which
absence it is" are the same promise at two levels of detail, and splitting them
would let a future reader satisfy one while contradicting the other.

Investigation also narrowed the fix. No new storage is needed: `doe_load_runs`
already records whether any load has succeeded and `doe_locality_reports` records
what each covered, so all four cases are already distinguishable from data on
hand. And the seed half turned out to need no mechanism either —
`supabase/config.toml` already carries `[db.seed] enabled = true`, so a
`supabase/seed.sql` is loaded after every reset. The file has simply never
existed.

## Fix tasks

_None._
