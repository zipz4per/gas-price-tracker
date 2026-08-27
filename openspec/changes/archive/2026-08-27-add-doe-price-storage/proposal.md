## Why

With coverage defined by `add-locality-registry`, the app needs somewhere to put the official DOE figures those localities point at. Until that exists there is no price baseline at all — and the baseline matters disproportionately here, because a crowdsourced price app has nothing to show on day one. Official data is what makes every station display a number before a single user has submitted anything.

The shape of that storage is dictated by what the source documents actually look like, which differs from the PRD's description of them in ways that matter:

- **The brand column set differs between regions**, and within a report a brand column is simply blank where a brand has no presence in a locality. A schema with a column per brand would need a migration whenever DOE adds or drops one.
- **Reporting periods are not weeks.** NCR publishes a 7-day span, CALABARZON a 3-day monitoring window, each labelled with different wording.
- **Missing data has four distinct source spellings** — an unavailable marker, the literal `None`, `0.00`, and `No LFRO` (no liquid fuel retail outlet) — and one of them means something quite different from the others.
- **Kerosene legitimately trades far above other fuels**, observed between ₱113 and ₱134 while gasoline sits in the ₱65–₱95 band.

Loading is manual in this change. The automated PDF parser is deliberately deferred: inspecting the source documents showed that naive text extraction silently mis-attributes prices to the wrong brands, because blank columns vanish from the text stream entirely. Correct parsing requires coordinate-based extraction, which is real engineering rather than a regular expression. At two documents per week, hand-entry costs minutes and keeps the project's highest-risk component off the critical path.

## What Changes

- **Introduce DOE reference price storage** holding per-locality, per-fuel-type, per-brand minimum, maximum, and common prices, keyed against the locality name as DOE publishes it.
- **Model loads as a three-level hierarchy** — a load run, the localities within it, and the price rows within those — so a run becomes visible atomically or not at all, and a failed or partial load can never degrade what is already stored.
- **Carry full provenance**: source document address, reporting period start and end, the period label verbatim as the document expresses it, and when the data was recorded.
- **Store one row per brand**, with a reserved `OVERALL` sentinel for the all-brands range, so a changing brand set is absorbed as data rather than as schema migrations.
- **Normalize the four absent-value spellings** into explicit states, keeping "no retail outlet in this locality" distinguishable from "data unavailable", and never storing any of them as a real price.
- **Treat zero rows for a registered locality as a run failure**, not as valid absence, so a renamed or misspelled source label surfaces instead of silently emptying a locality.
- **Validate against per-fuel-type plausibility bounds** rather than one global range.
- **Populate data by a documented manual process**, whose flat input format is also the interface a future automated parser will target.

### Explicitly out of scope

- The read path — retrieval, no-data results, freshness exposure — which is `add-doe-price-retrieval`.
- The automated PDF parser, address resolution, and any scheduling.
- Pushing to the hosted project; loads in this change run against the local stack.
- Station seed data, app UI, and crowdsourced price reports.

## Capabilities

### New Capabilities

- `doe-reference-prices`: Storage of official DOE pump-price reference data — record content, reporting-period semantics, provenance, normalized absent values, and the load-integrity rules that keep good data intact when a refresh fails. The retrieval half of this capability is added by `add-doe-price-retrieval`.

### Modified Capabilities

None.

## Impact

- **New:** Postgres tables for fuel types with per-fuel-type bounds, brands, load runs, per-locality load reports, and reference price rows; a loader function; RLS policies permitting public reads and no client writes.
- **New:** a documented manual data-entry procedure covering both report formats, including where each report is found and how to read its table.
- **Depends on:** `bootstrap-repo-and-supabase` for scaffolding and the migration path; `add-locality-registry` for the localities and source labels prices are recorded against.
- **Downstream:** `add-doe-price-retrieval` reads from these tables. A future automated parser produces the same flat input rows the manual procedure does, so it plugs into the loader without touching this schema.
- **Data sources:** two external DOE documents whose formats are outside project control, verified live at proposal time:
  - `prod-cms.doe.gov.ph/documents/d/guest/ncr-price-monitoring-08182026-pdf`
  - `prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-22-pdf`
- **Corrects PRD §7.2 (FR-6):** the proposed global ₱30–₱120 validation bound would reject real kerosene prices every week. Bounds must be per fuel type — which also applies to the crowdsourced submission path proposed later.
