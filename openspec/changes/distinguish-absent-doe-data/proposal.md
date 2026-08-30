# Say which kind of absence it is

## Why

Ask the system for RON 95 prices in Taguig City with an empty database and it
answers, for every station:

> No reference price: DOE does not report Petron for RON_95 in Taguig City.

That sentence is false. DOE reports Petron in Taguig City perfectly well; what
has happened is that nothing has ever been loaded. The system does not know the
difference, so it asserts the most specific of the possible explanations —
confidently, in fluent prose, with no error anywhere.

There are four distinct reasons a station can have no figure, and today they are
one:

```
  no succeeded load exists at all             -> nothing has been ingested
  loads exist, none covered this locality     -> this town has not been reported
  the locality was reported, not this fuel    -> no RON 95 figures that week
  the fuel was reported, not this brand       -> DOE did not monitor this brand
```

Only the fourth makes "DOE does not report Petron here" true. The first is a
statement about our own operations that the system presents as a fact about DOE.

This is the same failure the project has already fixed once. `get_doe_reference_prices()`
could not distinguish a request it could not parse from one it understood and had
no answer for, and `fix-unrecognised-read-inputs` corrected it on the argument
that these mistakes *"produce plausible wrong answers, so the only reliable
defence is making the wrong query impossible to express."* The same argument
applies one level along: the read path now understands the question and still
guesses at why it has no answer.

It was found by making the mistake. During verification of `add-station-registry`
a `supabase db reset` dropped the hand-loaded DOE rows, and an entire locality
reporting "DOE does not report this brand" was recorded as correct behaviour
before the empty table was noticed. Filed as `doe-data-lost-on-db-reset` (#17).

Neither spec forbids any of this. `doe-reference-prices` requires that absence be
explicit, and it is. `station-registry` requires that it not be a zero or a
blank, and it is not. Both are silent on whether the *stated reason* must be the
real one, so the implementation chose.

## What Changes

- **The reason for absence becomes part of the result.** `get_doe_reference_prices()`
  reports which of the four cases holds, on every row where there is no figure.
- **The station read path composes its sentence from that reason**, so a station
  with no figure says what is actually true rather than the most specific
  available guess.
- **The reason is never optional and never the caller's to infer.** A consumer
  cannot obtain the absence without the explanation, for the same reason it
  cannot obtain a brand range without the label saying what it is.
- **Loading becomes replayable.** `supabase/seed.sql` is generated from the
  recorded runs and committed, so `supabase db reset` restores DOE data instead
  of destroying it. `[db.seed]` is already enabled in `config.toml` and the file
  has simply never existed.

## Explicitly out of scope

- **Alerting or monitoring when a load is overdue.** Knowing that nothing has
  been loaded is a precondition for that and is not the same thing.
- **Automating the DOE ingestion.** `docs/doe-manual-load-procedure.md` argues
  the case for manual loading and this change does not reopen it.
- **Changing what counts as data.** Run gating, proxy attribution and
  absent-brand semantics are unchanged; only the explanation for their absence
  is new.
- **A new table.** The run ledger already records whether anything succeeded.
  Nothing here needs storage that does not exist.

## Capabilities

### Modified Capabilities

- `doe-reference-prices`: absence gains a reason, so the four cases stop being
  one.
- `station-registry`: a station's stated reason for having no reference price
  must be the true one.

## Impact

- **Modified:** `get_doe_reference_prices()` and its result type;
  `get_stations_with_reference_prices()` and its result type
- **New:** `supabase/seed.sql`, and a script that generates it from the recorded
  runs
- **Unchanged:** every table. The information needed already exists in
  `doe_load_runs`.
