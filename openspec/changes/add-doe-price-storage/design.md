## Context

See `proposal.md` — Why. This change builds on `bootstrap-repo-and-supabase` (scaffolding, migration path) and `add-locality-registry` (the localities and verbatim source labels prices are recorded against).

The constraints below come from inspecting the two live DOE documents, not from the PRD's description of them. They are the reason several decisions here diverge from what the PRD assumed:

- **Naive text extraction is unusable.** Extracted linearly, the CALABARZON report yields price rows with no city attached — every locality label appears exactly once, in a block far from the numbers. Worse, brands with no data emit nothing at all, so field counts vary row to row and a positional parser silently attributes prices to the wrong brand.
- **Coordinate-based extraction works.** Matching word y-position to product row and x-position to brand column recovers the table correctly, including the gaps that carry meaning.
- **Reporting periods differ**: NCR publishes `For the week of August 18-24, 2026` (7 days), CALABARZON `DATE MONITORING: August 18 - 20, 2026` (3 days).
- **Absent values have four spellings**: an unavailable marker, the literal `None`, `0.00`, and `No LFRO`.
- **Kerosene runs ₱113–₱134** while gasoline sits at ₱65–₱95.

Ingestion here is manual. This design's obligation to the future parser is to leave a clean seam, not to accommodate it now.

## Goals / Non-Goals

**Goals:**

- A storage model that absorbs both report formats without per-region schema branching.
- Load atomicity: a failed or partial load cannot degrade what is already stored.
- An operator-facing input format simple enough for weekly hand-entry, which is also the interface the future parser will target.

**Non-Goals:**

- Any read path. Retrieval, no-data results, and freshness exposure belong to `add-doe-price-retrieval`.
- Automated fetching, address resolution, or PDF parsing.
- Scheduling. Loads are operator-initiated.
- Historical trend analysis. Periods are retained, but nothing is designed around querying across them.
- Operator tooling beyond a documented procedure and a loader entry point — no admin UI.

## Decisions

### Store reference prices against the DOE source locality, not the app locality

Price rows are keyed by the locality name as DOE publishes it (`Tanauan City`). Resolving an app locality such as Malvar to its source happens at read time, through the registry.

*Why:* Malvar's figures **are** Tanauan City's figures. Storing them under `Malvar` would duplicate every row, and a second municipality proxying Tanauan later would duplicate them again — with the usual update anomalies when one copy is refreshed and another is not. Resolving at read time means one row set, and adding a proxy consumer costs one registry row.

*Alternative rejected:* denormalizing rows per app locality. Simpler to query, but it makes proxy relationships a write-time concern, which is exactly where they get forgotten.

### Three-level load hierarchy with visibility gated on run success

```
  doe_load_runs           one per document processed
    │  status: in_progress | succeeded | failed
    │  source_url, period_start, period_end, period_label
    ▼
  doe_locality_reports    one per locality within a run
    │  status: data | no_outlet
    ▼
  doe_reference_prices    one per fuel type × brand
       min, max, common (all nullable)
```

Readers only ever see rows belonging to a run marked `succeeded`.

*Why:* this makes "a failed or partial load must not destroy good data" structurally true rather than a rule someone has to remember. A run builds up invisibly and becomes visible atomically, or never. Nothing is overwritten in place, so the previous period stays queryable throughout. It also gives the zero-rows failure check a natural home: a `doe_locality_reports` row with status `data` and no child price rows is invalid, and fails its run.

*Alternative rejected:* upserting prices keyed on locality + fuel type + brand. Fewer tables, but a partial load silently leaves a mix of old and new figures, and there is no point at which the data is known-consistent.

*Trade-off:* three tables is more structure than a dataset this small needs. The next decision is what pays for it.

### Operator input is a single flat table; normalization happens in a loader function

The weekly procedure produces one flat file — one row per locality × fuel type × brand — which a loader function validates and expands into the three-level structure inside one transaction.

*Why:* it keeps hand-entry tolerable, and more importantly it is the **same seam the parser will use**. The future parser's job becomes "produce these flat rows," not "understand the storage model." That keeps the highest-risk change as small as it can be, and lets the manual path remain available as a fallback when the parser breaks — which, given the source documents, it eventually will.

### One row per brand, with `OVERALL` as a reserved brand sentinel

Rather than a column per brand, each fuel type gets one row per brand present, plus a row under the reserved brand `OVERALL` carrying the report's all-brands range.

*Why:* the brand set differs between NCR and CALABARZON, and DOE can add or drop brands without notice. A column-per-brand schema would need a migration each time. Row-per-brand absorbs the difference as data. It also makes "brands with no published data are omitted rather than zeroed" fall out naturally — an absent brand is an absent row, which is precisely what the source means when a column is blank.

*Alternative rejected:* a wide table with one column per brand. Faster to read, but it forces a schema migration on a source-side change and requires inventing a value for blank cells.

### Reporting periods are stored as explicit start and end dates

Both dates are stored, alongside the period label exactly as the document expresses it.

*Why:* the PRD's `report_week_start` / `report_week_end` assumes a week. CALABARZON reports a 3-day window. Naming the field for a week and storing a 3-day span in it would make every downstream "DOE data as of week of…" statement a small lie. Keeping the verbatim label means the app can render what the document actually said.

### Price plausibility bounds are per fuel type

Validation bounds are configured per fuel type, not as one global range.

*Why:* the PRD proposes a global ₱30–₱120 bound. Observed kerosene runs ₱113–₱134, so a global ceiling would reject valid data every week. This matters beyond this change: the same bound is proposed for crowdsourced submissions, where it would reject honest kerosene reports from real users.

### Reference data is public-read, with no client write path

RLS is enabled on all tables created here with a `SELECT` policy for anonymous and authenticated roles, and **no** insert, update, or delete policies. Loads run with the service role, out of band.

*Why:* reference data is authoritative-by-definition; there is no circumstance in which a client should modify it. Omitting write policies entirely — rather than writing restrictive ones — means there is no policy to get wrong. The service-role credential boundary established in `bootstrap-repo-and-supabase` is what keeps that key out of the repository.

## Risks / Trade-offs

- **Manual transcription errors** → The loader validates per-fuel-type bounds, `min ≤ max`, and that every registered locality expected in the document is present. A run failing validation is rejected whole, so a typo cannot land half a period. Every row carries its source address and period, so a bad run can be identified and superseded.
- **Manual entry does not scale and may quietly lapse** → Accepted deliberately: two documents per week. Freshness is exposed on every read once `add-doe-price-retrieval` lands, so lapsed data becomes visible rather than silent. If it lapses, that is evidence for prioritising the parser change.
- **Three-table hierarchy is more machinery than the data volume warrants** → Mitigated by the flat operator interface; the structure is invisible during normal weekly use.
- **A locality could be dropped from a DOE report entirely** → Treated as a run failure, not as absence. The previous period's data remains stored.
- **Storing against the DOE source locality couples proxy consumers to the source's fate** → If Tanauan City disappears from the report, Malvar loses its baseline. Acceptable: that is genuinely the situation, and surfacing it as a failure beats concealing it.
- **`OVERALL` as a reserved brand value** → A real brand named `OVERALL` would collide. Vanishingly unlikely, and the brand reference table would reject it on load.

## Migration Plan

Greenfield and additive: table creation plus reference-data seeds for fuel types and brands. No data migration and no backwards compatibility to preserve.

Rollback is dropping the created objects. Nothing reads this data yet — the read function arrives in `add-doe-price-retrieval` — so a rollback at this stage has no user-visible effect.

Deployment order within the change: lookup tables → load hierarchy tables → loader function → RLS policies. Development is local-first per `bootstrap-repo-and-supabase`; the first real loads run against the local stack, and the hosted push is deferred to `add-doe-price-retrieval` after verification passes.

## Open Questions

- **Retention of superseded periods.** Keeping every period is cheap at this volume and enables the PRD's post-V1 trend charts, so nothing is pruned for now. Whether to prune, and after how long, can be decided later without affecting this schema.
- **Where the future parser runs** — a Deno Edge Function versus a separate service — is deferred to the parser change. Coordinate-based extraction is required either way; the flat-rows seam means both choices plug into the same loader.
