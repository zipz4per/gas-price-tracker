## Context

See `proposal.md` — Why.

What exists: `localities` with direct and proxy sourcing modes, `brands` (ten real brands plus the `OVERALL` sentinel), and `doe_reference_prices` carrying brand-level ranges per locality report, served by `get_doe_reference_prices()` with proxy attribution and run-gated visibility.

Constraints that shape the approach:

- **DOE answers one question only.** It publishes what a brand charges across a municipality. It does not name, count, or locate a station, and it is not evidence about what exists on the ground.
- **A brand's DOE row already covers several stations.** Caltex RON 95 in Taguig spans ₱84.90–₱93.70; nine of twenty priced rows show a spread. A brand figure is true of the group and of no individual member.
- **A places provider is an external service** with its own licence terms, its own usage policy, and its own idea of what a station is called.
- **The presence of a station changes independently of DOE.** Stations open, close, and rebrand on their own schedule; a weekly price report is not a signal about any of that.

## Goals / Non-Goals

**Goals:**

- A station is a row a client can put on a map and a driver can recognise on arrival.
- Stations enter the registry from a source that actually knows what exists, and can be re-checked against it later.
- Every station shows a reference price immediately, labelled as a brand range rather than as its own price.

**Non-Goals:**

- Cross-checking the registry against DOE in either direction. The two sources answer different questions; agreement between them is not meaningful and disagreement is not a defect.
- Geocoding, map rendering, distance, or routing.
- Per-station observed prices. This change gives them somewhere to attach.
- Keeping the registry continuously fresh. Import is defined here; scheduling it is separate.

## Decisions

### The provider's place id is the station's identity across imports

Every station stores the provider's stable identifier alongside our own surrogate key. Matching on that id is what makes a re-import idempotent — without it, a second import matching on name and coordinates would create a near-duplicate every time a provider adjusted a pin or a station's listed name changed from "Petron" to "Petron Km 62".

It is also the only durable handle on a station that has closed. A place that stops being returned is identifiable by id; a place identified by name and position is not, because both can change while the station stays open.

### OpenStreetMap, queried through Overpass, is the provider

The design needs a provider with stable place ids; OpenStreetMap supplies them and costs nothing. A survey of the three served localities on 2026-08-28 returned **153 fuel stations** — Malvar 14, Lipa City 52, Taguig City 87 — with names, addresses, and coordinates, which is enough to open a map on.

It was chosen over Google Places on two grounds beyond price. Places caps how long most fields may be cached, which would have made the registry a 30-day cache with a permanent key; OSM's licence permits storing the data outright. And Places bills per request, which puts a meter on exactly the re-import this design depends on for staleness.

What it costs instead is a coverage guarantee. OSM is contributor-mapped, so a station that exists may simply not be in it, and 54 of the 153 carry no usable brand tag. There is no SLA and no support channel. The registry is therefore explicitly not exhaustive — which the design already assumed, and which the station-suggestion flow in the PRD (FR-20) is the eventual answer to.

### A locality is identified by OSM relation id, never by name

**Found while verifying the query, 2026-08-31.** Selecting an area by name is
wrong in two ways at once, and both fail quietly.

There is no boundary named "Lipa City". OSM calls it `Lipa`, so the obvious
query returns an empty result for a locality with 52 stations — which reads as
"no stations mapped here" rather than as a lookup failure.

And `Lipa` is not unique. A boundary search returns roughly twenty relations of
that name, in Poland, Slovenia, Estonia and the Philippines among others. An
area query by name would union them and import Polish fuel stations into a
Batangas locality, with plausible-looking rows and coordinates that only a
bounds check would catch.

So each locality stores the OSM relation id of its administrative boundary, and
the import queries `area(3600000000 + <relation id>)`. This is the same shape as
the DOE proxy mapping: a configuration value, not logic, so adding a locality is
a data change.

```
  Malvar        rel/5947753    admin_level=6
  Lipa City     rel/6209763    admin_level=6   named "Lipa" in OSM, not "Lipa City"
  Taguig City   rel/184776     admin_level=6   named "Taguig" in OSM
```

The OSM name is recorded beside the id precisely because it differs from ours.

### The place identifier is `type/id`, not `id`

OSM ids are unique only within an element type: `node/3743613230` and
`way/3743613230` are different objects and both may exist. The unique constraint
is therefore on the pair, stored as a single `provider_place_id` of the form
`way/338076890`, which is also how OSM itself addresses an element.

This matters because the registry contains all three types — Taguig alone
returns 5 nodes, 26 ways and 3 relations — so a bare integer key would collide
across types eventually rather than immediately, which is the worst schedule for
a bug like this.

### ODbL makes the station table share-alike, so it stays separable from our own data

OSM data is licensed under the Open Database Licence. Two obligations follow.

Attribution: any surface showing this data credits **© OpenStreetMap contributors** — that exact string, which is the form OSM's own copyright page gives. It is a client obligation, but it originates here, so the read path returns it alongside the stations (task 5.7) rather than leaving the client to remember it. A consumer that has to add attribution by hand is a consumer that will eventually ship without it.

Verified 2026-08-31: the licence is the **Open Data Commons Open Database License (ODbL) v1.0**, held by the OpenStreetMap Foundation. Every Overpass response carries the obligation in its own payload — `osm3s.copyright` reads *"The data included in this document is from www.openstreetmap.org. The data is made available under ODbL."* — so the import has no way to receive the data without also receiving the terms.

Share-alike: a table built by extracting OSM records is a Derivative Database, and publicly using one obliges us to offer it under ODbL. Our own data — observed prices, DOE reference figures, localities — sitting alongside it is a Collective Database, which carries no such obligation. The line holds only if the two stay distinguishable at the row level.

This lands on the same shape the previous draft reached from the opposite direction: provider-supplied name, address, and coordinates kept as a marked, refreshable set with a recorded fetch time, our own fields separate. Under Places terms that separation was a retention deadline; under ODbL it is a licence boundary. Either way the schema is the same, which is why it was worth designing before the provider was picked.

### The query asks for nodes, ways, and relations

Overpass returns only the element types the query names. `node[amenity=fuel]` across the corridor returned **21** elements; `nwr[amenity=fuel]` returned **193**. A station mapped as a building footprint is a way, and one mapped as a forecourt plus shop is a relation — 89% of the corridor is mapped that way, and a node-only query returns a plausible, quietly wrong answer rather than an error.

The import therefore queries `nwr` and takes `out center` so ways and relations yield a point. This is recorded because the failure is invisible: 21 stations is a believable number for a corridor, and nothing about the response says it is missing the other 172.

Confirmed independently on Malvar alone, 2026-08-31:

```
  node["amenity"="fuel"]   ->   2 elements
  nwr["amenity"="fuel"]    ->  10 elements   (2 nodes, 8 ways)
```

Two of ten. "Two petrol stations in Malvar" is exactly the kind of number a
reviewer accepts, and the response gives no hint that eight are missing.
`out center` supplies `center.lat`/`center.lon` for ways and relations, so the
import reads one shape regardless of element type.

The response carries what the schema needs, and not always:

```
  node/3743613230   name='Total'                    brand=None   addr: none
  node/12704871369  name='Felimon Magpantay'        brand=None   addr:street, town, postcode
  way/338076890     name='Malvar Shell Gas Station' brand='Shell' addr:street, town, postcode
```

Name is near-universal (92 of 96), `brand` is present on 69 of 96, and address
tags are sporadic. `Felimon Magpantay` is the review-list case arriving on the
very first locality — a real station with a personal name and no brand signal,
which is neither guessable nor droppable.

### Import runs server-side and off the request path

Overpass needs no API key, so there is no secret to leak — but the reason for keeping the provider call server-side survives the change of provider. Overpass is a free volunteer service with a usage policy that rules out per-page-view querying, and an import triggered by app traffic would be both a bad citizen and a dependency on someone else's uptime for a screen that should render from our own table.

Import is therefore a deliberate operation writing to `stations`; the client reads only our database and never contacts the provider.

The verification run made that concrete. Across roughly a dozen queries on
2026-08-31 the public endpoint returned *"runtime error … Dispatcher_Client::request_read_and_idx::timeout.
The server is probably too busy to handle your request"* several times, and the
`overpass.kumi.systems` mirror was unreachable altogether (no response in 90s).
Every failure arrived as an **HTTP 200 carrying an HTML error page**, not as a
non-200 status — so a client that checks the status code and parses the body as
JSON sees a parse error, and a client that catches that broadly sees an empty
result. An import that treated either as "no stations here" would silently empty
a locality. The import must therefore retry with backoff, and must distinguish a
provider failure from a genuinely empty area before writing anything.

### Brand resolution is rule-based, and unmatched names are surfaced

A provider returns "Petron Gas Station", "Shell Select", "Caltex — Star Mart", or a name with no brand in it at all. Resolution runs maintained rules against that text and produces a registered brand or nothing.

Nothing is guessed. A station filed under the wrong brand is shown the wrong brand's reference price — a wrong number attached to a real place, which is the failure this project keeps designing against. A dropped station is a hole in the map with nothing to indicate it. So an unmatched name goes to a review list, where it is either a new rule or a station genuinely outside the known brands.

`INDEPENDENT` is a registered brand and DOE reports figures for it, so an unbranded station is not automatically unresolvable — but it must be classified by a rule that says so, not by falling through to a default.

### Coordinates as plain numerics with a bounds check, not PostGIS

Latitude and longitude as `numeric`, constrained to Philippine bounds (roughly 4.5°–21.5°N, 116°–127°E). PostGIS would buy distance queries and spatial indexes; nothing in this change or the PRD's V1 needs either, and an extension should be justified by use rather than anticipated.

The bounds check catches a different class of error. A transposed pair — longitude written into latitude — is a valid number that places the station in the Pacific, and once stored it is indistinguishable from a correct one. This is the same reasoning that put per-fuel-type plausible bounds on prices.

### A station's reference figure is a brand range, and says so

The read path returns each station with the DOE range for its brand, locality, and fuel type, carrying the reporting period and any proxy attribution — the same obligations `get_doe_reference_prices()` already discharges, extended to a station.

```
  station              brand    locality range (DOE)   attribution
  Petron Km 62         PETRON   ₱89.20                 Tanauan City (proxy)
  Shell Poblacion      SHELL    ₱91.00 – ₱91.70        Tanauan City (proxy)
                                └── across all Shell in Tanauan City,
                                    not observed at this station
```

The label is part of the returned result rather than the client's responsibility, for the same reason proxy attribution lives in the read path: a consumer that has to remember to add it is a consumer that will eventually forget.

### Every station is registered; the reference price is what may be absent

DOE prices only the brands it happened to monitor, so filtering the registry to brands DOE prices would cut the map from 153 stations to 62 — and would drop stations that plainly exist. Lipa City would lose seven Shell and five Phoenix; Taguig City would lose five Flying V, five Seaoil, four Phoenix, three Total, and three Unioil. Malvar would show two pins.

```
  locality       OSM   brand DOE prices   brand DOE doesn't   unresolved
  Malvar          14           2                  2               10
  Lipa City       52          16                 15               21
  Taguig City     87          44                 20               23
  ──────────────────────────────────────────────────────────────────────
  TOTAL          153          62                 37               54
```

> **Re-measured 2026-08-31, and two of the three counts do not reproduce.**
> Method, now recorded so it can be repeated: `nwr["amenity"="fuel"]` inside
> `area(3600000000 + <relation id>)`, `out center tags`, against
> `overpass-api.de`.
>
> ```
>   locality      stations   named   brand tag   resolved   review
>   Malvar              10      10           5          5        5
>   Lipa City           52      48          39         32       20
>   Taguig City         34      34          25         23       11
>   ─────────────────────────────────────────────────────────────
>   TOTAL               96      92          69         60       36
> ```
>
> Lipa City matches the survey exactly at 52, which is what makes the other two
> worth taking seriously rather than dismissing as method drift — the same query
> reproduces one number precisely and misses the others by 4 and 53. A wider
> bounding box over Taguig returns 342, so 87 is not a bbox either; the original
> survey's area definition was not recorded and cannot now be reconstructed.
>
> The measured figures are the ones to plan against, because they are the ones
> with a method attached. The DOE-priced split is left as surveyed: recomputing
> it needs the `brands` and `doe_reference_prices` tables, and the local stack is
> not available at the time of writing. The argument the table exists to support
> is unaffected and slightly strengthened — filtering the registry to brands DOE
> prices still removes stations that plainly exist, and 36 of 96 names still
> resolve to nothing.
>
> Task 6.5's expected counts are updated to match, so the import's own check
> fires on a real shortfall rather than on a number nobody can reproduce.

A Lipa City map without a Shell on it does not read as a scoped V1; it reads as broken. And the driver standing at that Shell is not helped by being told it does not exist.

So every station the provider returns is registered, and the reference price is the value that may be absent — returned as an explicit no-reference marker rather than a zero, a blank, or an omitted row. This is the same contract `get_doe_reference_prices()` already keeps for a locality with no data, applied one level down.

It gives the client three states rather than two: a reported price, no report but a brand range, and neither. The third is not an edge case — it is at least 37 of 153 stations today, before any of the 54 unresolved names are settled.

### A locality with no stations is not an error

The registry starts empty and fills locality by locality. No stations for a locality returns no stations, distinguishable from a locality that is not registered at all — the same explicit-absence contract the reference-price read path already follows.

## Risks / Trade-offs

- **ODbL share-alike reaches the stations table** → provider-derived rows stay separable from our own data so the obligation is bounded to what it actually covers; attribution is carried to any surface that displays it.
- **OSM coverage is contributor-driven and unguaranteed** → the registry does not claim to be exhaustive, and a station missing from OSM is a gap the eventual suggestion flow closes, not a defect here.
- **Overpass is a free volunteer service with a usage policy** → import is deliberate and server-side, never per page view; three localities is small volume by construction.
- **A node-only query looks like it worked** → the import queries `nwr` with `out center`, and the element-type mix is worth checking whenever the query is changed.
- **Brand rules will miss names** → by design they surface rather than guess; the review list is the maintenance surface and is expected to be non-empty.
- **A provider may list a station that has closed, or miss one that is open** → out of scope to detect here. The place id makes a later reconciliation possible; nothing in this change claims the registry is exhaustive or current.
- **Brand ranges will read as station prices anyway**, however labelled → mitigated by the label being part of the result, not the client's choice.
- **Coordinates are only bounds-checked**, so a station placed in the wrong barangay stores fine → beyond any constraint; the address field and review are the defence.

## Migration Plan

Additive. New table and read path; no existing table, function, or policy changes. The registry starts empty and an empty registry returns no stations rather than failing.

## Open Questions

- How many of the 54 unresolved names are genuinely independent stations. `INDEPENDENT` is a brand DOE prices in Malvar and Lipa City but not in Taguig City, so the answer changes how many stations carry a reference price — but it is a question for the review list in task 4.2, not one that blocks the schema.
