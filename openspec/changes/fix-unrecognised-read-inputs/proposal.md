## Why

`get_doe_reference_prices()` cannot say "I did not understand that." Asked for a fuel type it does not recognise, it answers `has_data = false` — the same well-formed reply it gives when a locality genuinely has no figures for a real fuel type. So `'RON 95'` reports no data for Malvar while `'RON_95'` returns seven priced rows, and `'BANANA'` reports no data with equal confidence. The bug is filed as `openspec/bugs/doe-fuel-type-not-recognised`.

Not understanding a request is a different fact from having no answer to it, and the read path currently has no way to express the difference. That gap is what makes the wrong answer convincing: `Absence of reference data is an explicit state` is a requirement written to make the system honest, and it is precisely what camouflages a request the system never parsed.

The same gap sits on the other argument, where it contradicts a requirement already written. `locality-registry` says an unregistered locality is one the system **reports** as not covered; the read path returns an empty set and reports nothing. A caller cannot tell "Santo Tomas is outside our coverage" from "the query matched no rows", which is the same collapse in a different costume.

Both are worth fixing now rather than after the first client screen exists. A consumer that guesses an input wrong should learn that immediately, in development, rather than shipping a screen that confidently tells a driver there is no fuel price.

## What Changes

- **Recognise a fuel type against the registered set** before answering, so an argument matching none of the seven codes in `fuel_types` is rejected rather than answered.
- **Reject an unrecognised locality the same way**, replacing the silent empty result with an explicit report that the locality is not covered — discharging a `locality-registry` requirement the read path has never met.
- **Match a fuel type code by the same normalization localities already use**, so `'RON 95'`, `'ron_95'`, and `'RON_95'` all resolve to the same code and only a genuinely unknown value is rejected.
- **Keep absence untouched.** A registered locality with no run, and a real fuel type with no figures, still return the explicit `has_data = false` row. This change adds a state for a question the system cannot answer; it does not change any answer it can.
- **Name what was not recognised, and what would have been.** A rejection says which argument failed and what the valid values are, because an error a caller cannot act on sends them to the source anyway.

### Explicitly out of scope

- Changing how reference prices are ingested, stored, or attributed. Only the read path's treatment of its own arguments changes.
- The station read path in `add-station-registry`. It inherits this shape and should follow the requirement once it exists, but it is not built yet.
- Client behaviour, retries, or error rendering. This change makes the distinction expressible; what a client does with it is the client's.
- Fuzzy matching or suggestions. Normalization is deliberately not fuzzy — `'Taguig Cty'` and `'Taguig City'` must stay distinct, and the same restraint applies here.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `doe-reference-prices`: gains a requirement that an unrecognised request is a distinct state from an absent answer, and that a fuel type is matched by normalization against a registered set.

## Impact

- **Modified:** `public.get_doe_reference_prices()` — validates both arguments before answering, and rejects rather than returning a no-data row for an unrecognised one. **BREAKING** for any caller relying on an unregistered locality returning an empty set; none exists yet.
- **New:** a normalization for fuel type codes, matching the one localities already use.
- **Modified:** `openspec/bugs/doe-fuel-type-not-recognised/report.md` — its `Fixed by` and `What the fix changed` sections, once this lands.
- **Depends on:** `fuel_types` and `localities` as the registered sets that define what "recognised" means.
- **Unblocks:** the first client screen, which would otherwise render a confident wrong answer on a mistyped fuel type, and the station read path, which would inherit the same ambiguity.
