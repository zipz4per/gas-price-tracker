## Context

See `proposal.md` — Why. This change builds on `bootstrap-repo-and-supabase` (scaffolding, hosted link), `add-locality-registry` (sourcing modes, proxy attribution), and `add-doe-price-storage` (the tables being read).

The relevant inherited constraints:

- Price rows are keyed by the **DOE source locality** (`Tanauan City`), not the app locality. Resolving Malvar to Tanauan happens here, at read time.
- Loads are three-level, and only rows under a run marked `succeeded` are legitimate.
- Brands with no published data have no row at all, because a blank source column means the brand is absent rather than free.

No client application exists, and the platform question remains open. This change therefore delivers a read path with no consumer, which shapes how it is verified.

## Goals / Non-Goals

**Goals:**

- Proxy attribution that a consumer cannot accidentally drop.
- Run visibility enforced at read time, so the storage layer's atomicity guarantee holds end to end.
- An absence representation that lets a consumer render a sensible empty state.
- A hosted deployment performed only after local verification passes.

**Non-Goals:**

- Any client, UI, or presentation decision — including how proxy attribution is worded to a user.
- Caching, pagination, or query performance work beyond the indexes already created.
- Cross-period or historical queries. Retrieval targets the current period.
- Automated ingestion or scheduling.

## Decisions

### Reads go through a single server-side function

Retrieval is one database function taking a locality and fuel type, returning brand rows, overall range, period, freshness, and proxy attribution together.

*Why:* three separate obligations converge here — the registry join for proxy resolution, latest-succeeded-run selection, and the absent-brand semantics — and every one of them fails silently when done wrong. A consumer that omits proxy attribution shows a plausible number attributed to the wrong municipality. A consumer that queries tables directly can read a failed run's rows. Neither error surfaces as an error. Consolidating them server-side means a caller cannot express the wrong query.

*Alternative rejected:* exposing tables and letting clients join. More flexible, and every client would need to re-derive run visibility and proxy labelling correctly, forever, including clients not yet written.

### Proxy attribution is part of the result, not metadata a caller may request

The attribution field is always present in the return shape — naming the source locality for proxied data, empty for direct.

*Why:* an optional field is one a caller can forget to select. Making it unconditional means the only way to discard it is deliberately, which is a reviewable act rather than an oversight.

### Absence is a distinct result from error and from empty

A registered locality with no ingested data returns an explicit no-data result; the call succeeds.

*Why:* PRD §7.1 (FR-3) requires the app never show a blank or broken screen when data is missing — which is the normal state at launch, before any load has run for a locality. Modelling absence as an error would push every consumer into try/catch for an expected condition; modelling it as an empty result makes it indistinguishable from a zero-priced fuel.

### Stale data is served, not withheld

When the latest succeeded run is several periods old, its figures are returned with their period rather than suppressed.

*Why:* PRD NFR-2 prefers visibly-old data over nothing. Manual loading will lapse occasionally, and a stale price with a visible date is more useful to a driver than an empty screen. Freshness is exposed so the consumer can decide how loudly to say so — that judgement belongs to the UI, not to the query.

### Hosted deployment is last, and only after local verification

Migrations reach hosted via `supabase db push` once local verification passes, and the loads are re-run there.

*Why:* the local-first model from `bootstrap-repo-and-supabase` exists so that destructive iteration is free. Pushing earlier would forfeit that for no benefit, since nothing consumes the hosted data yet. Deferring it to the last change means hosted receives a schema that has already been exercised end to end.

## Risks / Trade-offs

- **A read path with no consumer may have the wrong return shape** → Real risk, since the first client is changes away. Mitigated by verifying against the spec's scenarios directly, and by the return shape being derived from the PRD's station-detail requirements (FR-2) rather than invented. A lightweight throwaway consumer would de-risk it further if the shape proves awkward.
- **Function-only access is less flexible than table access** → Intended. If a future consumer needs a different shape, the fix is another function with the same guarantees, not opening the tables.
- **Proxy attribution can still be dropped by a consumer that receives and ignores it** → Unavoidable at this layer; the database cannot force a screen to render a field. This change guarantees the information is always delivered, which is the strongest available control.
- **Hosted and local can diverge if the dashboard is used to edit schema** → The local-first decision forbids it. This is a discipline risk, not one the tooling enforces.

## Migration Plan

Additive: one function plus RLS verification. No data migration.

Rollback is dropping the function; the underlying data is untouched, so reversal is safe and immediate.

Deployment order: create and verify the function locally → verify all specs' scenarios → push migrations to hosted → re-run both loads against hosted → verify all three localities resolve identically to local. The hosted push is the last step of the last change deliberately, so any problem found earlier costs nothing to fix.

## Open Questions

- **Whether a corridor-ordered retrieval is wanted** — returning localities along the Malvar→BGC route in travel order rather than one at a time. Deferred until there is a UI to know whether it is used that way; it would be an additional function, not a change to this one.
- **Whether retrieval should accept multiple fuel types in one call.** Single-fuel-type is sufficient for the station-detail shape in PRD §7.1; batching is an optimisation with no consumer to justify it yet.
