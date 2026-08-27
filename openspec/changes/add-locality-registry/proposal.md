## Why

The app's coverage — which localities it serves and where each one's official price data comes from — is the foundation every other part of the system reads from. It has to exist before there is anywhere to put DOE prices, and its shape is constrained by an awkwardness in the source data.

The primary user drives a commute corridor, living in Malvar, Batangas and working in BGC/Taguig, so the product question is "where along my route is fuel cheapest," not "what does my town charge." Covering that corridor means three localities across two DOE regions, and they do not resolve the same way:

- **Malvar does not appear in any DOE report.** Its figures must be borrowed from neighbouring Tanauan City, which means proxied data has to be labelled as such wherever it is shown, or users will believe they are seeing official figures for their own town.
- **Lipa City and Taguig City appear directly**, under their own names, in two different regional reports.
- **Those reports address themselves differently.** The NCR report's location embeds its reporting date and is constructible; the CALABARZON report's ends in an opaque incrementing counter and can only be discovered. Any later automated ingestion needs this recorded as configuration rather than assumed to be one scheme.
- **Source documents contain errors.** The NCR report spells Taguig as `Taguig Cty`. Matching on the intended name silently finds nothing.

Building only Malvar first would bake the proxy case in as the default rather than as one of two modes. Establishing the registry with both modes present from the start makes coverage a data concern permanently.

## What Changes

- **Introduce a locality registry** recording each covered locality's display name, province or region label, DOE region, and sourcing mode — `direct` where the locality appears in a DOE report under its own name, `proxy` where a neighbour's rows stand in.
  - Malvar, Batangas → `proxy` via **Tanauan City** (Region IV-A CALABARZON)
  - Lipa City, Batangas → `direct` (Region IV-A CALABARZON)
  - Taguig City, NCR → `direct` (NCR Price Monitoring)
- **Require proxy attribution to travel with the data**, so proxied figures cannot be presented as official data for the borrowing locality.
- **Introduce DOE region source configuration**, recording each region's report location and how the current report's address is determined — date-derived for NCR, discovery-based for CALABARZON.
- **Make locality matching normalized and tolerant but not fuzzy** — insensitive to case, whitespace, and punctuation, with the expected source label stored verbatim including any misspelling. Deliberately no edit-distance matching.
- **Guarantee coverage is extended by configuration alone**, so adding a locality, changing a sourcing mode, or repointing a proxy never requires a code change.

### Explicitly out of scope

- Any storage or loading of DOE price data — that is `add-doe-price-storage`.
- Any retrieval of prices — that is `add-doe-price-retrieval`.
- Station seed data, app UI, and crowdsourced price reports.
- Batangas City and Lian, which also appear in the CALABARZON report and are deferred by request.

## Capabilities

### New Capabilities

- `locality-registry`: The set of localities the app covers and how each resolves to DOE reference data — direct versus proxy sourcing, the DOE region each belongs to, how source labels are matched, and the provenance labelling obligations that follow from proxy sourcing.

### Modified Capabilities

None.

## Impact

- **New:** Postgres tables for the locality registry and DOE region source configuration, with a locality label normalization function and RLS policies permitting public reads and no client writes.
- **Depends on:** `bootstrap-repo-and-supabase` for version control, Supabase scaffolding, and the migration path.
- **Downstream:** `add-doe-price-storage` records prices against the DOE source localities this registry names; `add-doe-price-retrieval` resolves proxy attribution through it. Station seeding and any future UI also key off this registry.
- **Data sources:** the two DOE documents that define the expected source labels, verified live at proposal time:
  - `prod-cms.doe.gov.ph/documents/d/guest/ncr-price-monitoring-08182026-pdf`
  - `prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-22-pdf`
- **Revises PRD §4:** the V1 launch area becomes three localities across two DOE regions rather than Malvar alone. The PRD's requirement that proxy mapping be configuration rather than code is preserved and extended.
