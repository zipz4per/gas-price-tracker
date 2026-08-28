## Why

The database has no concept of a gas station. It knows brands, and it knows what each brand's prices are across a whole municipality, but a driver does not visit a municipality's Petron — they pull into one specific station on one specific road. Every user story in the PRD opens with a list or map of stations, and nothing in the schema can produce one.

DOE cannot supply those stations. Its report is a price document: brand-level ranges for a municipality, published weekly. It never names a station, never counts them, and never places one on a map. Caltex in Taguig City reports RON 95 between ₱84.90 and ₱93.70 — an ₱8.80 spread no single station can have in one monitoring period, so even that row is several stations collapsed into one line, with nothing to say how many or where. Treating the report as evidence about the physical world would be reading it for something it does not claim to answer.

Which stations exist and where they are is a places question, and it belongs to a places provider — OpenStreetMap, queried through Overpass — whose entire purpose is knowing what is on the ground. That also makes the registry maintainable: stations open, close, and rebrand, and a provider that tracks them is a better source than a list typed out once.

So the two sources answer two different questions, and neither substitutes for the other. The provider says a station exists at a location and carries a brand. DOE says what that brand charges across the municipality. A station's displayed price is the second, attributed to the first — until per-station reports arrive.

## What Changes

- **Introduce a station as a first-class, mappable entity** — an individually identifiable place with a name, a brand, a locality, an address, and coordinates, so a station can be listed and shown on a map.
- **Source stations from an external places provider** rather than from DOE or from a hand-typed list, and record the provider's stable identifier for each station so it can be refreshed, de-duplicated, and re-checked as stations open and close.
- **Register every station the provider returns**, whether or not DOE prices its brand in that locality, and make the reference price the value that may be absent — an explicit no-reference state rather than a missing station.
- **Carry the source's required attribution with the data**, and keep provider-derived fields distinguishable from data the system originates.
- **Model a station's brand as an attribute of the station**, not as a substitute for it: a locality holds many stations, and several of them may carry the same brand.
- **Map a provider's free-text station name to a registered brand** through maintained rules, surfacing any name that cannot be mapped rather than guessing at it.
- **Use DOE for prices only.** The system must not infer from the DOE report that a station exists, how many there are, or where one is; a brand's absence from the report says nothing about the presence of stations carrying it.
- **Attribute reference prices to a station through its brand and locality**, so every station shows a DOE range today, labelled as a locality-wide brand range rather than as a price observed at that station.
- **Cover every locality the app serves** — Malvar, Lipa City, and Taguig City — rather than the launch municipality alone.

### Explicitly out of scope

- Crowdsourced price reports, device identity, and rate limiting. This change gives those a station to attach to; it does not build them.
- Map rendering, routing, distance, and any client application.
- Automated or scheduled refresh of the station registry from the provider. This change establishes the registry and how stations enter it; keeping it continuously current is its own concern.
- Changing how DOE prices are ingested, stored, or retrieved. That capability is read here and otherwise untouched.

## Capabilities

### New Capabilities

- `station-registry`: What a gas station is, how it is identified and located, how it enters the registry from a places provider, how its brand is determined, and how a reference price is attributed to it.

### Modified Capabilities

None. `doe-reference-prices` and `locality-registry` are read by this change but keep their requirements unchanged.

## Impact

- **New:** a `stations` table keyed by locality and brand, carrying the provider identifier, name, address, and coordinates.
- **New:** a read path returning the stations in a locality with the DOE reference range applicable to each, so a client can render a station list without joining tables itself.
- **New:** a dependency on OpenStreetMap as an external places provider, whose ODbL terms oblige the system to attribute the data and to keep provider-derived rows separable from data the system originates.
- **Modified:** `PRD.md` — FR-19 and §5 describe stations as hand-seeded for Malvar because DOE lacks per-station data. The premise is right and the conclusion is not: the answer is a places provider, across every covered locality.
- **Depends on:** `locality-registry` for the localities a station belongs to, and `doe-reference-prices` for brands and reference ranges.
- **Unblocks:** the first client screen, crowdsourced price reports, and every PRD user story that begins with a list of stations.
