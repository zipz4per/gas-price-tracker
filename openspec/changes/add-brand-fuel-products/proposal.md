## Why

A driver at a Petron forecourt reads "Blaze" and "XCS" off the canopy. A driver at a Shell reads "V-Power" and "FuelSave". Nobody reads "RON 95". If the price submission form asks for RON grades, it asks a question in a vocabulary the person is not standing in front of, and the most likely outcomes are a wrong grade or an abandoned report.

The grade is still the right thing to *store* — DOE reports by RON, and prices are only comparable across brands in those terms. What is wrong is showing it. The brand's own product name and the canonical fuel type are two views of one thing, and nothing in the schema currently connects them.

There is a second, quieter reason. Brands do not sell every grade, and a form offering seven fields where the station sells four invites a price to be entered against a product that does not exist there.

## What Changes

- **Introduce a per-brand fuel product catalogue** mapping a brand and a canonical fuel type to the name that brand sells it under, so a submission form can speak the signage while storing the grade.
- **Make the catalogue authoritative about what a brand sells.** A fuel type absent from a brand's entries is a fuel type that brand does not offer, and must not be offered for submission at its stations.
- **Order products as the brand presents them**, rather than by RON descending, so the form reads like the canopy.
- **Define the unbranded fallback as a first-class case, not a degradation.** 36 of 96 registered stations are `INDEPENDENT` or have no resolved brand — 38% — so the generic, grade-named form is the second most used surface in the app and is specified as such.
- **Promote the real chains currently pooled in `INDEPENDENT`.** The bucket holds at least six multi-station operators — Uno Fuel (4), Gazz/Petro Gazz (3), Nitro (2), RePhil (2), Fuel Express (2), Maxfill (2) — which are national or regional brands, not independents.
- **Normalize brand names before matching them.** `Gazz` and `Petro Gazz`, `Maxfill` and `MaxFill` are the same operator reaching the registry under two spellings; matching rules that do not fold case and common prefixes will keep splitting them.
- **Record the catalogue as a maintained surface with a stated review path**, alongside `brand_name_rules` and `docs/station-brand-review.md`. Product lineups change with rebrands, and a mapping that silently goes stale shows a driver a product name their station retired.

### Explicitly out of scope

- **The submission form itself.** This change supplies what the form displays; `add-price-reports` owns when and by whom a price may be submitted.
- **Brand visual identity** — colours, logos, and any asset licensing.
- **Changing how a station's brand is resolved from its provider name.** The resolution rules are extended with new brands here; the mechanism is untouched.
- **The four stations whose name is their OSM identifier.** They have no brand and no name to show; they fall to the generic form like any unbranded station, and repairing their provider data is a registry concern.
- **Inferring a brand's product line from observed reports.** The catalogue is curated, not learned.

## Capabilities

### New Capabilities

- `brand-fuel-products`: What a brand sells, under what name, in what order, and how a station with no identified brand is handled; how the catalogue is maintained and how a stale entry is caught.

### Modified Capabilities

- `station-registry`: "A provider's station name resolves to a registered brand" gains normalization before matching, and the brands it can resolve to expand beyond those DOE prices — a brand may now exist because it sells fuel, not because DOE reports it.

## Impact

- **New:** a `brand_fuel_products` table keyed by brand and fuel type, carrying the brand's product name and its presentation order.
- **New:** brand records for operators DOE does not price, which makes `brands` a registry of who sells fuel rather than a projection of who appears in the DOE report.
- **New:** rules promoting the pooled chains out of `INDEPENDENT`, and case- and prefix-folding in name resolution.
- **Modified:** `docs/station-brand-review.md` — the review surface grows a second question. Not only "which brand is this station?" but "does this brand's product list still match its signage?"
- **Depends on:** `station-registry` for brand resolution, and the registered fuel types for the grades products map onto.
- **Unblocks:** the brand-specific submission form in `add-price-reports`.
- **Cost accepted:** a third hand-curated naming surface. It is recorded here rather than absorbed into another change so the maintenance burden is visible.
