## Context

See `proposal.md` — Why, and `openspec/bugs/doe-fuel-type-not-recognised/report.md` for the reproduction.

What exists: `get_doe_reference_prices(p_locality, p_fuel_type)` resolves the locality through `normalize_locality_label()`, finds the latest succeeded run, and returns per-brand rows — or a single `has_data = false` row when the locality is registered but has no figures. `fuel_types` is a closed table of seven codes; `localities` holds three.

Constraints that shape the approach:

- **The two arguments are already treated differently.** Localities are normalized; fuel types are compared with `=`. Three normalized comparisons and two exact ones sit in one function body, and nothing recorded which was intended.
- **The function's own header says the quiet part.** *"None of those mistakes raises an error. They produce plausible wrong answers, so the only reliable defence is making the wrong query impossible to express."* That reasoning was applied to proxy attribution, run visibility, and absent brands, and not to the arguments themselves.
- **`has_data = false` is a documented, correct state.** It cannot be repurposed to mean "I did not understand", because a consumer already reads it as "understood, nothing to show".
- **There are no callers yet.** The read path ships but nothing consumes it, so a behaviour change costs nothing today and costs a migration later.

## Goals / Non-Goals

**Goals:**

- A caller that passes something the read path cannot interpret finds out, immediately and unambiguously.
- A caller that names a fuel type in a reasonable spelling gets the figures.
- Every answer the function can currently give correctly, it still gives.

**Non-Goals:**

- Suggesting a correction, or matching fuzzily. Rejection names the valid set; choosing among it is the caller's.
- Changing ingestion, storage, attribution, or the no-data contract.
- Applying this to the station read path. It should follow, but it does not exist yet.

## Decisions

### An unrecognised argument raises rather than returning a row

`raise exception` with a `check_violation`-class message, surfacing through PostgREST as a client error the caller cannot mistake for data.

The alternative was a third state in the result — a `recognised` flag beside `has_data`, or a sentinel row. It was rejected because it puts a caller-error signal in every successful row's shape, and because it repeats the mistake being fixed: a caller who ignores `has_data` today would ignore `recognised` tomorrow, and the response would again be well-formed and wrong. A raised error cannot be ignored into a plausible answer.

This does not contradict `Absence of reference data is an explicit state`, which forbids an error for a request that was understood and has no data. That case is untouched. The new error is for a request that was never a question the system could answer.

```
  request                        before                    after
  ─────────────────────────────────────────────────────────────────────────
  Malvar, RON_95                 7 rows                    7 rows
  Malvar, RON 95                 1 row, has_data = false   7 rows
  Malvar, KEROSENE (no figures)  1 row, has_data = false   1 row, has_data = false
  Malvar, BANANA                 1 row, has_data = false   error
  Atlantis, RON_95               0 rows                    error
```

### Fuel types are normalized by the function localities already use

`normalize_locality_label()` lowercases, maps punctuation to a space, collapses whitespace, and trims. Under it `'RON 95'`, `'ron_95'`, and `'RON_95'` all become `ron 95`.

Writing a second normalizer for fuel codes would mean two definitions of "the same string" in one function, which is how the original asymmetry arose. The function's name mentions localities and its behaviour does not; that is a naming problem worth its own small change, not a reason to duplicate it.

Its comment already records the restraint this needs: *"Intentionally NOT fuzzy — 'Taguig Cty' and 'Taguig City' must stay distinct."* A fuel type that normalizes to nothing registered is unrecognised, not rounded to a neighbour.

### The registered code is what comes back

A caller asking for `'RON 95'` receives rows whose `fuel_type` reads `RON_95`. Today the function echoes `p_fuel_type` verbatim into the no-data row, so a caller could receive their own spelling back as though it were the system's.

Echoing the input makes the response a mirror; returning the resolved code makes it an answer. It also means a client that stores what it received stores the registered code, not whatever a screen happened to send.

### The locality half discharges an existing requirement

`locality-registry` already says an unregistered locality is one the system **reports** as not covered. Returning an empty set reports nothing — it is indistinguishable from a query that matched no rows, which is the same collapse this change exists to fix, one argument over.

So this half is not new scope. It is a requirement the read path has never met, and the current comment — *"An unregistered locality is not covered, which is a different fact from having no data, so it returns nothing at all"* — states the right principle and then implements silence.

### The error names the valid set

`fuel_types` and `localities` are both public-readable and small. An error that says only "unrecognised" sends the caller to the schema; one that lists the seven codes ends the question.

There is nothing to leak: `localities_public_read` already grants `anon` a full read of the registry, so the error exposes nothing a caller could not select.

## Risks / Trade-offs

- **A raised error can reach a user as a broken screen**, which PRD FR-3 forbids → FR-3 governs absent data, which still returns a renderable no-data result. An unrecognised argument is a caller defect, and it should be loud in development rather than papered over in production.
- **Breaking change for callers relying on the empty set** → there are none; the read path ships unconsumed. This is the cheapest moment it will ever have.
- **Reusing a locality-named function for fuel types reads oddly** → accepted deliberately over a duplicate definition of the same normalization; renaming it is a separate, smaller change.
- **Normalization admits spellings the project never intended to support** → bounded by the registered set: a variant is accepted only when it normalizes to a real code, so the accepted surface is seven values however they are punctuated.

## Migration Plan

One migration replacing the function body. The signature, the result type, and every currently correct answer are unchanged; what changes is that two previously silent inputs now raise. No data migration, no backfill, nothing to reverse beyond replacing the function.

## Open Questions

None.
