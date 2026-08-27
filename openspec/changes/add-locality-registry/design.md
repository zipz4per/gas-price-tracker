## Context

See `proposal.md` — Why. This change builds on `bootstrap-repo-and-supabase`, which supplies version control, Supabase scaffolding, and the migration path. No schema exists yet.

The constraints shaping this design come from inspecting the two live DOE source documents rather than from the PRD's description of them:

- **Two report formats, two addressing schemes.** The NCR report's address embeds its reporting date and is therefore constructible; the CALABARZON report's address ends in an opaque incrementing counter and can only be discovered.
- **Source labels contain errors.** The NCR report spells Taguig as `Taguig Cty`. The CALABARZON report lists Batangas province localities as `Batangas City`, `Lian`, `Lipa City`, and `Tanauan City` — with `Batangas` also appearing as a province name.
- **Malvar is absent** from the CALABARZON report entirely, which is what forces the proxy concept.

## Goals / Non-Goals

**Goals:**

- Coverage expressible entirely as data, so adding a locality or repointing a proxy never touches code.
- A matching rule strict enough that a price can never be attributed to the wrong locality.
- Region addressing recorded as configuration, so a later ingestion process implements two strategies rather than assuming one.

**Non-Goals:**

- Storing or retrieving price data. The registry names localities; it holds no prices.
- Fetching or parsing any DOE document.
- Deciding how price rows are keyed — that decision belongs to `add-doe-price-storage`, where it becomes real.

## Decisions

### Conservative normalization for locality matching, and exactly-one-match required

Matching normalizes case, surrounding whitespace, and punctuation, and nothing else. No edit-distance or fuzzy similarity. A registry entry must resolve to exactly one source label; zero matches and multiple matches both fail.

*Why:* fuzzy matching is how `Taguig Cty` would be handled automatically — and also how `Batangas City` could quietly absorb rows belonging to `Batangas` the province, which appears in the same document. Mis-attributed prices are worse than absent ones, because they are indistinguishable from correct data downstream: a driver sees a plausible number and has no way to know it came from the wrong town. The registry instead stores the expected source label verbatim, typo included, so tolerance is declared per locality rather than inferred.

*Alternative rejected:* trigram or Levenshtein matching against locality names. It would handle `Taguig Cty` without configuration, at the cost of silent mis-attribution risk that grows with every locality added.

### The expected source label is stored separately from the display name

Each registry entry carries both the name shown to users (`Taguig City`) and the label expected in the source document (`Taguig Cty`).

*Why:* it keeps a source-side error from leaking into the product. It also makes the error visible and documented in one place rather than encoded as a workaround somewhere in a parser, and means a corrected source document is a one-row data fix.

### Region addressing is configuration, not code

Each DOE region records its report address pattern and a resolution strategy: derivable from the reporting date, or requiring discovery.

*Why:* the PRD assumed a single URL scheme with an incrementing suffix. That is true of CALABARZON and false of NCR, whose slug is a date. Recording the distinction now means the later ingestion change implements two strategies deliberately instead of discovering the mismatch after building one. It also isolates the project's most fragile external dependency behind data.

### Sourcing mode is a registry attribute, not a special case

`direct` and `proxy` are two values of one field rather than a general path and a Malvar exception.

*Why:* Malvar is currently the only proxy, and a design that treats it as a special case would make the second proxy a code change. Modelling both modes from the start is what makes the coverage-by-configuration guarantee real rather than aspirational — including the case where DOE begins publishing Malvar directly and the fix is flipping one field.

## Risks / Trade-offs

- **Requiring exactly one match makes runs fail on source-side renames** → Intended. A failure is recoverable by updating one registry row; silent mis-attribution is not recoverable because nobody knows it happened.
- **Storing a known typo looks like a bug to a future reader** → Mitigated by keeping display name and source label as distinct fields, so the intent is legible rather than looking like a mistake.
- **Proxy attribution is only enforceable where it is read** → This change requires attribution to travel with resolved data, but cannot force a consumer to display it. `add-doe-price-retrieval` closes this by making retrieval a single server-side function that always returns attribution alongside the figures.
- **A proxy's fate is coupled to its source locality** → If Tanauan City disappears from the report, Malvar loses its baseline. Acceptable: that is genuinely the situation, and surfacing it beats concealing it.

## Migration Plan

Greenfield and additive: table creation plus reference-data seeds for the two DOE regions and the three localities. No data migration and no backwards compatibility to preserve.

Rollback is dropping the created objects. Nothing consumes the registry yet, so a rollback at this stage has no user-visible effect.

Development is local-first per `bootstrap-repo-and-supabase`: built and verified against the local stack, pushed to hosted only after verification.

## Open Questions

- **Whether Batangas City and Lian should be added** once the registry is proven. Deferred by request; adding them is a seed change requiring no code or schema change.
- **Whether localities eventually need a corridor or route grouping** to support "prices along my route" ordering. Deliberately left flat for now — the corridor is why these three localities were chosen, not yet a concept the data model needs. Adding it later is additive.
