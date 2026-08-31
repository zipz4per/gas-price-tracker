## Why

`add-brand-fuel-products` built the catalogue and left it empty. Not by oversight — the rule it set for itself is that a product name and its canonical grade come from the brand's own published page, never from memory or a third-party summary, because a wrong entry is indistinguishable from a right one to anyone reading the table later. Applied honestly across nine national brands and three regional chains, that rule produced nothing that could be committed.

Only Petron publishes a lineup a machine can read. Its sitemap lists the fuel products and each page states a grade — Blaze 100 as "Premium Plus Grade (RON 100)", XCS as "Premium Plus Grade Ethanol-blended Gasoline (RON 95+)", Xtra Advance as "Regular Grade" for engines that "can run on 91 RON fuel". Its two diesels then stop it: Turbo Diesel and Diesel Max Euro 4 are both "Distillate fuel with additive" and both describe themselves as premium, with nothing separating `DIESEL` from `DIESEL_PLUS`. Shell and Caltex render their fuel pages in JavaScript and serve 70 and roughly 6,200 characters of navigation to a static fetch. Seaoil, Phoenix and Flying V answer 404 on `/products/`. PTT, Unioil and TotalEnergies yield nothing at all.

Seeding Petron's three gasoline grades alone was considered and rejected there, and the reasoning still holds: the catalogue is authoritative, so a Petron list without diesel would stop twenty stations accepting a diesel report on one of the two fuels DOE actually covers.

So this is a data problem with a different blocker from the code it fills, and it is separated for that reason. The schema, the fallback, and the submission check are finished and running; what is missing is a readable source. Holding a completed change open until a brand redesigns its website serves nobody.

## What Changes

- **Establish where a lineup may be read from**, beyond a brand's marketing pages: product data sheets, safety data sheets, and specification documents published by the brand all state a grade and are frequently reachable when the product page is not.
- **Seed the brands whose lineups can be sourced**, recording for each entry the page it came from and the date it was consulted.
- **Resolve Petron's two diesels**, or record that they cannot be resolved from published sources and leave both out rather than guessing which is `DIESEL`.
- **Leave unsourceable brands empty and say why.** `brands.products_review_note` already carries what was tried; this change updates those notes rather than replacing them with silence.
- **Verify each seeded lineup against the reference data**, checking that every fuel type DOE reports for a brand appears in that brand's product list, and investigating any that does not — a brand DOE prices for a grade it supposedly does not sell is a contradiction one of the two sources is wrong about.

### Explicitly out of scope

- **Any schema change.** `brand_fuel_products`, `brands.products_verified_at`, `brands.products_source_url`, `brands.products_review_note`, `get_station_fuel_options`, and the catalogue check in `submit_price_report` all exist and are unchanged by this.
- **Rendering a JavaScript page.** Adding a headless browser to reach two brands' marketing pages is a dependency this project does not have and would carry for one purpose.
- **Inferring a grade from a product name.** "Blaze 100" naming its octane is a convenience, not a source; the grade is taken from the page's own statement or the product is not seeded.
- **Lineups for the six regional chains.** Uno Fuel, Petro Gazz, Nitro, RePhil, Fuel Express and Maxfill have little or no web presence; they fall back to canonical grade names, which is a supported surface.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. `brand-fuel-products` already specifies what the catalogue holds, that an absent fuel type means a brand does not sell it, and that a brand without entries falls back to canonical grade names. This change supplies rows the existing requirements already describe and alters none of them, so `.openspec.yaml` sets `skip_specs: true`.

## Impact

- **New:** rows in `brand_fuel_products` for each brand whose lineup can be sourced, and `products_verified_at` and `products_source_url` set on those brands.
- **Modified:** `brands.products_review_note` for brands that stay unsourced, updated with what was tried this time.
- **Behavioural consequence, worth stating because it is the point:** a brand that gains a catalogue stops offering fuel types absent from it. Twenty Petron stations currently accept a report for any of the seven registered fuels; once Petron has entries they accept only what Petron sells. That is the intended effect and it is the reason a partial lineup is worse than none.
- **Depends on:** `add-brand-fuel-products` for every table and function it writes to.
- **Unblocks:** the submission form asking in the words on the canopy rather than in RON grades, which is the reason the catalogue exists.
