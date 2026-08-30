# Design

## Context

Four distinct situations produce "no reference price", and the read path reports
all four as the fourth:

```
  A  no succeeded run exists at all         our ingestion never ran
  B  runs exist, none cover this locality   this town has not been reported
  C  locality reported, this fuel type not  no figures for RON 95 that week
  D  fuel reported, this brand carried none DOE did not monitor this brand
```

`get_doe_reference_prices()` already branches on some of this — it has separate
code paths for "no run for this locality" and "run exists but not this fuel type"
— but both emit the same shape, a single row with `has_data = false` and nothing
saying which happened. A and B share one branch entirely.

The station read path then composes prose from that shape and has only one
sentence available:

```sql
format('No reference price: DOE does not report %s for %s in %s.', ...)
```

which asserts D unconditionally.

**Everything needed to tell them apart already exists.** `doe_load_runs` records
every load and its status; `doe_locality_reports` records which localities a run
covered. No table is added by this change.

## Goals / Non-Goals

**Goals**

- A no-data result says which of the four cases it is.
- A station's stated reason is the true one.
- `supabase db reset` stops destroying hand-loaded data.

**Non-Goals**

- Alerting when a load is overdue. Distinguishing A is a precondition for that,
  not the same thing.
- Automating ingestion, or revisiting the manual-load argument.
- Changing run gating, proxy attribution, or absent-brand semantics.

## Decisions

### An enum, resolved in escalation order

```
  no_data_ingested        no run has ever succeeded                    (A)
  locality_not_covered    succeeded runs exist, none for this locality (B)
  fuel_type_not_reported  the locality was reported, this fuel was not (C)
  brand_not_reported      the report carried no figure for this brand  (D)
```

Checked in that order and stopping at the first that holds, because they nest:
with no runs at all, every locality is uncovered and every brand unreported. The
most general true statement is the only honest one, and reporting a more specific
reason than the evidence supports is precisely the defect.

`has_data` stays. It is a real, specified concept and the enum does not replace
it; the enum says *why* when it is false, and is null when it is true.

### The reason is not an ignorable flag

`fix-unrecognised-read-inputs` rejected adding a `recognised` boolean beside
`has_data` on the grounds that *"a caller who ignores has_data today would ignore
recognised tomorrow"*. That argument applies here and is the reason the fix is
not simply "expose the reason and let callers use it".

It is answered at the place the mistake is actually made. The false sentence is
composed **inside** `get_stations_with_reference_prices()`, not by any client, so
that function taking the reason as its input makes the wrong sentence impossible
to express rather than merely discouraged. A client cannot compose its own reason
because the reason it is given is already prose.

For `get_doe_reference_prices()` the enum is not nullable when `has_data` is
false, so a no-data row without a reason cannot be produced.

### Seeding, not a new store

The bug report's own framing: *"A saved payload or a seed file is the smaller
half; the distinguishable state is the part that needs a requirement."*

The smaller half is smaller than it looked. `supabase/config.toml` already
carries `[db.seed] enabled = true`, and Supabase loads `supabase/seed.sql` after
every `db reset`. The file has simply never existed. Generating it from the
recorded runs and committing it makes a reset restorative instead of
destructive, with no mechanism to build.

It also makes the loaded data reviewable in git, which a hand-typed payload
living only in a database never was.

The seed is generated, not hand-maintained: a script reads `doe_load_runs`,
`doe_locality_reports` and `doe_reference_prices` and writes inserts. Hand-editing
it would recreate the original problem one level along.

### Why the station path keeps composing prose

An alternative is to return the enum to the client and let it choose wording.
That is where the wrong sentence would come back: four cases, one of which is
embarrassing to the operator, and a client author with no context deciding how to
phrase them. The label for a brand range is already composed server-side for the
same reason, and this is the same obligation.

## Risks / Trade-offs

- **A wider result type.** Two more fields on two result types, both of which
  clients must not ignore. Mitigated by the reason arriving as finished prose in
  the station path, where ignoring it means displaying nothing rather than
  displaying something false.
- **Case A is a statement about us, shown to users.** "No reference data has been
  ingested" is an operational admission. It is still better than a confident lie
  about DOE, and it is the string most likely to prompt someone to fix it.
- **The seed file will drift from hosted.** It is a snapshot, regenerated when a
  load happens. A stale seed restores stale figures — which carry their own
  reporting period, so they are visibly stale rather than silently wrong.
- **Escalation order hides co-occurring causes.** A locality that is both
  uncovered and whose station has no brand reports only the first. Accepted:
  reporting every applicable reason is noise, and the most general one is the one
  that must be fixed first.

## Open Questions

- Whether case A should also surface on the `has_data = true` path when the most
  recent successful run is old. That is staleness rather than absence, the period
  is already returned, and it belongs with the overdue-load alerting that this
  change puts out of scope.
