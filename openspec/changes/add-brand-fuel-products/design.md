## Context

See `proposal.md` — Why, and `specs/brand-fuel-products/spec.md` for the behaviour required.

Three existing facts shape the approach:

- **Brand resolution already exists** — `resolve_station_brand(brand, operator, name)` tries the provider's `brand`, `operator`, then `name` fields against `brand_name_rules` patterns, and yields a brand only on a unique match. This change extends what it matches against, not how it decides.
- **`brands` carries `is_retailer`**, and `stations` references it through a composite foreign key so a non-retailer row such as `OVERALL` cannot be attached to a station. The catalogue needs the same guarantee for the same reason.
- **The registry already has a review surface** — `stations_needing_brand_review` paired with `docs/station-brand-review.md`. A second curated list should extend that pattern rather than invent a second one.

## Goals / Non-Goals

**Goals:**

- One lookup that answers "what fuels do I offer at this station, and what do I call them", correct for a branded station, an unbranded one, and a branded one with no catalogue entries.
- Brand-name normalization that merges spellings of one operator without merging distinct operators.
- Staleness in the catalogue that is found by review rather than by a driver.

**Non-Goals:**

- Brand visual identity. Colours and logos carry licensing questions this change does not open.
- Any change to how `resolve_station_brand` decides between candidates. Only the input it matches is normalized.
- A per-station product list. The catalogue is per brand; a branch that stocks something unusual is not modelled.

## Decisions

### The catalogue is keyed by brand and fuel type, guarded by the same composite key as stations

```
brand_fuel_products
  brand_code        ─┐
  brand_is_retailer ─┴─▶ brands(code, is_retailer)   generated true
  fuel_type_code    ───▶ fuel_types(code)
  product_name
  sort_order
  primary key (brand_code, fuel_type_code)
```

`brand_is_retailer` is a generated column fixed at `true` with a composite foreign key, mirroring `stations`. It makes "a product cannot name a non-retailer brand" a constraint rather than a check somebody has to remember — the `OVERALL` row cannot acquire a product list.

### Last-verified is recorded on the brand, not on the product

The review action is "open this brand's site and compare its lineup", which happens once per brand and covers every row at once. A per-product timestamp would record the same date many times and would go stale in fragments, which is harder to review than a single date per brand.

`brands.products_verified_at` plus a `brands_needing_product_review` view, alongside the existing `stations_needing_brand_review`. A 180-day interval to start: rebrands and product renames run on a scale of years, so a shorter interval produces review work with nothing to find.

### The fallback is resolved in SQL, keyed by station

```
get_station_fuel_options(p_station_id)
  station has a brand with catalogue entries  ─▶ brand's products, brand's order
  station has a brand with no entries         ─▶ canonical grades
  station has no resolved brand               ─▶ canonical grades
```

One function, three inputs, one shape out. **Why not let the client fall back.** A client that must remember to substitute canonical names when a lookup returns empty is a client that will, on one screen, render an empty list instead — and that screen serves 36 of 96 stations. The same reasoning that put `reference_basis` inside the read path applies: the case that is easy to forget is the case that must not be forgettable.

### Normalization folds whole words, never substrings

Matching happens against a normalized name: lower-cased, and with a maintained list of corporate affixes removed **only when they appear as complete words**.

The word-boundary condition is not a refinement, it is the whole safety property. `Petro Gazz` and `Gazz` are one operator and must fold together; `Petron` is a different operator and must not be touched. A substring rule that strips `petro` merges all three and leaves `Petron` as `n`. Folding on `\y` word boundaries — the same construct `brand_name_rules` patterns already use — keeps `Petron` intact because `petro` is not a word within it.

**Alternative considered: normalize the stored patterns instead of the incoming name.** Rejected — the provider's variation is in the incoming data, so the rules would need one pattern per spelling, which is the duplication this decision exists to remove.

### Promoted chains are re-resolved in place, not left to the next import

Adding brand rows and rules changes nothing about stations already recorded as `INDEPENDENT`. The migration therefore re-runs resolution over existing stations so the registry is consistent when the migration finishes, rather than at some later import that may not be scheduled.

This is safe now in a way it would not have been before: `add-price-reports` makes a station's reference figure locality-wide, so changing a station's brand no longer changes the price it displays. The two changes are complementary — one removes brand from the pricing path, which is what makes the other free to correct brands in bulk.

### Product names are seeded only from each brand's published lineup

Initial rows are compiled from the brands' own product pages, and `products_verified_at` is set to the date that was done. Lineups recalled from memory or taken from third-party summaries are not a source; a wrong product name is indistinguishable from a right one to anyone reviewing the table later, which is exactly the failure `products_verified_at` exists to catch.

### The uncatalogued-fuel rejection lives in the submission path

`specs/brand-fuel-products/spec.md` requires a submission for an uncatalogued fuel at a branded station to be rejected. That check belongs in whatever function accepts a report, which `add-price-reports` introduces.

Either change may land first. If this one does, the check is written into the submission function when it is created; if the other does, this change adds the check to it. Nothing here depends on that ordering.

## Risks / Trade-offs

- **Over-folding merges distinct operators.** The affix list is the dangerous surface: one careless entry silently pools two brands, and the result looks like successful resolution. → Word-boundary folding only, and a test asserting that known-distinct pairs — `Petron` against `Petro Gazz` most of all — stay distinct after normalization.

- **A curated lineup is wrong from the start.** Nothing detects a product name that was never right. → Seeding from published sources only, with the verification date recorded, so a wrong entry is at least attributable to a date and a source rather than to nobody.

- **The catalogue silently narrows what can be reported.** Making the catalogue authoritative means a missing row removes a fuel from the app. A brand that does sell RON 97, recorded without it, cannot receive RON 97 reports and gives no sign that it is refusing them. → The review view surfaces brands by verification age; a brand with an implausibly short product list is visible there.

- **A third hand-curated naming surface.** `brand_name_rules`, `docs/station-brand-review.md`, and now the catalogue, each stale in its own way. → Accepted, and recorded in the proposal rather than absorbed silently. The mitigation is that all three share one review document and one review cadence.

- **Four stations have no name at all**, their provider identifier standing in. They fall to the generic path correctly, but they are also unlabelled in any list. → Out of scope here; a registry data-quality concern.

## Migration Plan

1. `brand_fuel_products` with the composite foreign key, RLS, and read grants.
2. `brands.products_verified_at`, and the `brands_needing_product_review` view.
3. Brand rows for the pooled operators — Uno Fuel, Petro Gazz, Nitro, RePhil, Fuel Express, Maxfill — with `is_retailer = true`.
4. Name normalization in `resolve_station_brand`, with the affix list, plus the rules for the new brands.
5. Re-resolve existing stations, and report how many moved out of `INDEPENDENT`.
6. Seed the catalogue from published lineups; set `products_verified_at`.
7. `get_station_fuel_options`, with the two fallback cases.
8. The uncatalogued-fuel rejection in the submission path, wherever it exists by then.

Steps 1–3 and 6–7 are additive. Step 4 changes an existing function's behaviour and step 5 rewrites station rows; both are reversible by restoring the previous function body and re-resolving, since resolution is derived from provider data that is retained.

## Open Questions

- **The review interval.** 180 days is a starting value; observed rebrand frequency can adjust it without touching the specs.
- **Whether genuinely single-site independents eventually get their own brand rows.** The catalogue makes this possible but the registry gains little from 23 single-station brands; deferrable until a second station of one of them appears.
