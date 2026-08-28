## Why

`add-doe-price-storage` puts official DOE figures into the database. Nothing can read them yet, and the way they are read carries a correctness obligation that a plain table query cannot satisfy.

Malvar's prices are Tanauan City's prices. Every consumer that shows them must say so, or a driver in Malvar will believe they are seeing official DOE figures for their own municipality when no such figures exist. That is not a presentation preference — it is the difference between showing data and misrepresenting its source. If retrieval is left to callers joining tables, each one re-derives proxy resolution independently, and any that forgets fails silently and looks correct.

Two further pieces of logic have the same property. Selecting the latest *succeeded* load run is what makes the storage layer's atomicity guarantee real at read time; a caller that queries the tables directly can see rows from a failed or in-progress run. And distinguishing "no data for this locality" from an error, or from data borrowed off a neighbouring fuel type, determines whether the app can render a sensible empty state instead of a broken screen.

Consolidating all three behind one server-side entry point is what turns them from rules a consumer must remember into properties a consumer cannot avoid.

This change also carries the first push to the hosted project, deliberately last: the schema is proven locally before it reaches the environment that will eventually hold real data.

## What Changes

- **Introduce a single server-side retrieval path** taking a locality and fuel type, returning the per-brand ranges available, the overall range, the common price where published, the reporting period, and any proxy attribution that applies.
- **Resolve proxy sourcing transparently**, so a request for Malvar returns Tanauan City's figures together with the attribution naming Tanauan City as the source, without the caller needing to know Malvar is proxied.
- **Return only data from the latest succeeded load run**, so rows from failed or in-progress runs are never visible.
- **Make absence of data an explicit result** rather than an error or an empty value, and never borrow figures across fuel types or localities.
- **Omit brands with no published data** rather than returning them zeroed or null-priced, preserving what a blank source column actually means.
- **Expose data freshness** — the reporting period and recording timestamp — on every result, so a consumer can show how current the figures are and detect staleness.
- **Serve stale data rather than withholding it**, so a lapsed load degrades to old figures with a visible date rather than to an empty screen.
- **Push the verified schema to the hosted Supabase project** and re-run the loads there.

### Explicitly out of scope

- The automated PDF parser, address resolution, and scheduling.
- Station seed data, app UI, and crowdsourced price reports.
- Any client application. This change delivers the read path, not a consumer of it.

## Capabilities

### New Capabilities

- `doe-reference-prices`: The retrieval half of this capability — how reference data is read, what a caller receives, how proxy attribution and run visibility are resolved, and how absence and staleness are represented. `add-doe-price-storage` introduces the storage half; the two changes contribute disjoint requirements to the same capability and archive into one spec.

### Modified Capabilities

None.

## Impact

- **New:** a Postgres retrieval function resolving the registry join, proxy attribution, and latest-succeeded-run selection; RLS policies confirming the read path is reachable anonymously.
- **New:** the hosted Supabase project receives its first schema push and its first data.
- **Depends on:** `bootstrap-repo-and-supabase` for scaffolding and the hosted link; `add-locality-registry` for sourcing modes and proxy attribution; `add-doe-price-storage` for the data being read.
- **Downstream:** any future consumer — a station list, a corridor view, a throwaway HTML page — reads through this function. The proxy-labelling obligation in PRD §7.1 (FR-2) is satisfied structurally rather than by convention.
- **Satisfies PRD §7.1 (FR-3):** a station or locality with no reference data yields an explicit no-data state rather than a blank or broken screen.
