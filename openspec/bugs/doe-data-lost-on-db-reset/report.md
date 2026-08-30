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

_Pending._

## What the fix changed

_Pending._

## Does this need a change?

_Not yet decided._

<Leaning yes, added requirement. The likely shape is that the system should be
able to distinguish "no DOE data has ever been loaded" from "DOE reported
nothing for this brand", which nothing in `openspec/specs/` currently promises —
`doe-reference-prices` requires absence be an explicit state but says nothing
about the absence of the whole dataset. A saved payload or a seed file is the
smaller half; the distinguishable state is the part that needs a requirement.>

## Fix tasks

_None._
